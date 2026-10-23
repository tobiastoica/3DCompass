import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:compass_3d/data/services/arcore_canvass_service.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/domain/models/position_estimate.dart';
import 'package:compass_3d/domain/repositories/sensor_fusion_repository.dart';
import 'package:compass_3d/domain/use_cases/canvass_building_use_case.dart';
import 'package:compass_3d/domain/use_cases/track_live_position_use_case.dart';

/// Manages the real-time building surveying and ARCore canvassing workflow.
class CanvassingViewModel extends ChangeNotifier {
  /// Creates a canvassing view model.
  CanvassingViewModel({
    required CanvassBuildingUseCase canvassBuildingUseCase,
    required TrackLivePositionUseCase trackLivePositionUseCase,
    required ArCoreCanvassService arCoreService,
    SensorFusionRepository? sensorFusionRepository,
  })  : _canvassBuildingUseCase = canvassBuildingUseCase,
        _trackLivePositionUseCase = trackLivePositionUseCase,
        _arCoreService = arCoreService,
        _sensorFusionRepository = sensorFusionRepository;

  final CanvassBuildingUseCase _canvassBuildingUseCase;
  final TrackLivePositionUseCase _trackLivePositionUseCase;
  final ArCoreCanvassService _arCoreService;
  final SensorFusionRepository? _sensorFusionRepository;

  bool _isSurveying = false;
  String _buildingName = '';
  int _activeFloor = 0;
  final Map<String, NavNode> _surveyedNodes = {};
  final List<NavEdge> _surveyedEdges = [];
  final List<FloorLevel> _floors = [
    const FloorLevel(
      floorIndex: 0,
      name: 'Ground Floor',
      baseElevationMeters: 0.0,
      floorHeightMeters: 3.6,
    ),
  ];

  NavNode? _lastWalkNode;
  Coordinates3D _currentPosition = Coordinates3D.zero;
  int _detectedPlaneCount = 0;
  double _currentHeadingDegrees = 0.0;
  int _stepCount = 0;
  StreamSubscription<PositionEstimate>? _posSub;
  StreamSubscription<ArPlaneData>? _planeSub;

  // Active vertical staircase/elevator transition tracking
  bool _isTraversingStairs = false;
  VerticalTransition? _activeTransitionType;
  int? _targetStairFloor;
  NavNode? _stairDepartureNode;

  /// Whether surveying is actively recording.
  bool get isSurveying => _isSurveying;

  /// The name of the building being surveyed.
  String get buildingName => _buildingName;

  /// The current vertical floor index.
  int get activeFloor => _activeFloor;

  /// All registered floor levels so far.
  List<FloorLevel> get floors => List.unmodifiable(_floors);

  /// The number of waypoints marked so far.
  int get waypointCount => _surveyedNodes.length;

  /// The number of structural planes detected by ARCore.
  int get detectedPlaneCount => _detectedPlaneCount;

  /// The live user coordinates.
  Coordinates3D get currentPosition => _currentPosition;

  /// The live heading in degrees.
  double get currentHeadingDegrees => _currentHeadingDegrees;

  /// The step count during this survey.
  int get stepCount => _stepCount;

  /// Whether the user is currently climbing or descending stairs between floors.
  bool get isTraversingStairs => _isTraversingStairs;

  /// The target floor index being climbed to or descended to.
  int? get stairTargetFloor => _targetStairFloor;

  /// The active transition type (stairs or elevator).
  VerticalTransition? get activeTransitionType => _activeTransitionType;

  /// Starts a new canvassing survey session at doorway [buildingName].
  Future<void> startSurvey(String buildingName, {int initialFloorCount = 1}) async {
    _buildingName = buildingName;
    _surveyedNodes.clear();
    _surveyedEdges.clear();
    _detectedPlaneCount = 0;
    _stepCount = 0;
    _activeFloor = 0;
    _isTraversingStairs = false;
    _targetStairFloor = null;
    _stairDepartureNode = null;

    // Reset sensor fusion datum to origin to eliminate stale offset artifacts
    _sensorFusionRepository?.resetPosition(Coordinates3D.zero);
    _currentPosition = Coordinates3D.zero;

    // Seed requested initial floors (e.g. 1 to 4 floors)
    _floors.clear();
    for (var i = 0; i < math.max(1, initialFloorCount); i++) {
      _floors.add(FloorLevel(
        floorIndex: i,
        name: i == 0 ? 'Ground Floor' : 'Floor $i',
        baseElevationMeters: i * 3.6,
        floorHeightMeters: 3.6,
      ));
    }

    _isSurveying = true;
    notifyListeners();

    await _arCoreService.startSession();

    // Mark Doorway Anchor
    const doorwayNode = NavNode(
      id: 'entrance_main',
      name: 'Main Doorway Entrance',
      position: Coordinates3D.zero,
      floorIndex: 0,
      type: NodeType.doorway,
    );
    _surveyedNodes[doorwayNode.id] = doorwayNode;
    _lastWalkNode = doorwayNode;

    // Emit initial structural entrance plane
    _arCoreService.emitPlane(ArPlaneData(
      id: 'plane_entrance_0',
      center: doorwayNode.position,
      extentX: 2.5,
      extentZ: 2.5,
      type: ArPlaneType.horizontalUpwardFacing,
      boundaryPolygon: [
        doorwayNode.position.translate(dx: -1.25, dy: -1.25),
        doorwayNode.position.translate(dx: 1.25, dy: -1.25),
        doorwayNode.position.translate(dx: 1.25, dy: 1.25),
        doorwayNode.position.translate(dx: -1.25, dy: 1.25),
      ],
    ));

    // Listen to live movement
    _posSub = _trackLivePositionUseCase.execute().listen((estimate) {
      _stepCount++;
      _currentHeadingDegrees =
          (estimate.orientation.azimuthRadians * 180.0 / math.pi % 360.0 + 360.0) % 360.0;

      // In survey mode, horizontal tracking comes from PDR, while activeFloor stays pinned to user selection
      _currentPosition = Coordinates3D(
        x: estimate.position.x,
        y: estimate.position.y,
        z: _activeFloor * 3.6,
      );

      final distSinceLast = _lastWalkNode != null
          ? _lastWalkNode!.position.distanceTo(_currentPosition)
          : 0.0;

      // Automatically place corridor waypoints and structural planes every 1.5m or 3 steps (suppressed while on stairs)
      if (!_isTraversingStairs && _lastWalkNode != null && (distSinceLast >= 1.5 || (_stepCount % 3 == 0 && distSinceLast >= 0.8))) {
        final corridorId = 'corridor_${_surveyedNodes.length}';
        final newNode = NavNode(
          id: corridorId,
          name: 'Corridor WP',
          position: _currentPosition,
          floorIndex: _activeFloor,
          type: NodeType.hallway,
        );

        _surveyedNodes[newNode.id] = newNode;
        _surveyedEdges.add(NavEdge(
          sourceNodeId: _lastWalkNode!.id,
          targetNodeId: newNode.id,
          distanceMeters: distSinceLast,
          transitionType: VerticalTransition.walk,
        ));

        // 1. Emit structural corridor floor plane
        _arCoreService.emitPlane(ArPlaneData(
          id: 'plane_corridor_${_surveyedNodes.length}',
          center: _currentPosition,
          extentX: 2.4,
          extentZ: distSinceLast.clamp(1.0, 4.0),
          type: ArPlaneType.horizontalUpwardFacing,
          boundaryPolygon: [
            _lastWalkNode!.position.translate(dx: -1.2),
            _lastWalkNode!.position.translate(dx: 1.2),
            _currentPosition.translate(dx: 1.2),
            _currentPosition.translate(dx: -1.2),
          ],
        ));

        // 2. Emit structural left and right wall planes
        _arCoreService.emitPlane(ArPlaneData(
          id: 'plane_wall_l_${_surveyedNodes.length}',
          center: _currentPosition.translate(dx: -1.2, dz: 1.5),
          extentX: distSinceLast.clamp(1.0, 4.0),
          extentZ: 3.0,
          type: ArPlaneType.vertical,
          boundaryPolygon: [
            _lastWalkNode!.position.translate(dx: -1.2),
            _currentPosition.translate(dx: -1.2),
            _currentPosition.translate(dx: -1.2, dz: 3.0),
            _lastWalkNode!.position.translate(dx: -1.2, dz: 3.0),
          ],
        ));

        _arCoreService.emitPlane(ArPlaneData(
          id: 'plane_wall_r_${_surveyedNodes.length}',
          center: _currentPosition.translate(dx: 1.2, dz: 1.5),
          extentX: distSinceLast.clamp(1.0, 4.0),
          extentZ: 3.0,
          type: ArPlaneType.vertical,
          boundaryPolygon: [
            _lastWalkNode!.position.translate(dx: 1.2),
            _currentPosition.translate(dx: 1.2),
            _currentPosition.translate(dx: 1.2, dz: 3.0),
            _lastWalkNode!.position.translate(dx: 1.2, dz: 3.0),
          ],
        ));

        _lastWalkNode = newNode;
      }
      notifyListeners();
    });

    // Listen to ARCore Plane Detection
    _planeSub = _arCoreService.detectedPlaneStream.listen((_) {
      _detectedPlaneCount++;
      notifyListeners();
    });
  }

  /// Explicitly switches the active surveying floor.
  void selectFloor(int floorIndex) {
    _activeFloor = floorIndex;
    _ensureFloorExists(floorIndex);
    _currentPosition = Coordinates3D(x: _currentPosition.x, y: _currentPosition.y, z: floorIndex * 3.6);
    notifyListeners();
  }

  /// Adds a new floor to the building model and switches to it.
  void addFloor(String name, {int? specificIndex}) {
    final newIndex = specificIndex ??
        (_floors.isEmpty ? 0 : (_floors.map((f) => f.floorIndex).reduce(math.max) + 1));
    _ensureFloorExists(newIndex, customName: name.isNotEmpty ? name : null);
    selectFloor(newIndex);
  }

  void _ensureFloorExists(int floorIndex, {String? customName}) {
    if (!_floors.any((f) => f.floorIndex == floorIndex)) {
      _floors.add(FloorLevel(
        floorIndex: floorIndex,
        name: customName ?? (floorIndex == 0 ? 'Ground Floor' : 'Floor $floorIndex'),
        baseElevationMeters: floorIndex * 3.6,
        floorHeightMeters: 3.6,
      ));
      _floors.sort((a, b) => a.floorIndex.compareTo(b.floorIndex));
    }
  }

  /// Manually drops a named point of interest (e.g. Room, Office, Amenity).
  void markPointOfInterest(String name, NodeType type) {
    final id = 'poi_${_surveyedNodes.length}_${name.replaceAll(' ', '_')}';
    final node = NavNode(
      id: id,
      name: name,
      position: Coordinates3D(x: _currentPosition.x, y: _currentPosition.y, z: _activeFloor * 3.6),
      floorIndex: _activeFloor,
      type: type,
    );

    _surveyedNodes[id] = node;
    _ensureFloorExists(_activeFloor);

    // Emit structural POI / Room floor plane
    _arCoreService.emitPlane(ArPlaneData(
      id: 'plane_poi_${_surveyedNodes.length}',
      center: node.position,
      extentX: 3.5,
      extentZ: 3.5,
      type: ArPlaneType.horizontalUpwardFacing,
      boundaryPolygon: [
        node.position.translate(dx: -1.75, dy: -1.75),
        node.position.translate(dx: 1.75, dy: -1.75),
        node.position.translate(dx: 1.75, dy: 1.75),
        node.position.translate(dx: -1.75, dy: 1.75),
      ],
    ));

    // Emit structural room wall planes
    _arCoreService.emitPlane(ArPlaneData(
      id: 'plane_poi_wall_n_${_surveyedNodes.length}',
      center: node.position.translate(dy: 1.75, dz: 1.5),
      extentX: 3.5,
      extentZ: 3.0,
      type: ArPlaneType.vertical,
      boundaryPolygon: [
        node.position.translate(dx: -1.75, dy: 1.75),
        node.position.translate(dx: 1.75, dy: 1.75),
        node.position.translate(dx: 1.75, dy: 1.75, dz: 3.0),
        node.position.translate(dx: -1.75, dy: 1.75, dz: 3.0),
      ],
    ));
    _arCoreService.emitPlane(ArPlaneData(
      id: 'plane_poi_wall_s_${_surveyedNodes.length}',
      center: node.position.translate(dy: -1.75, dz: 1.5),
      extentX: 3.5,
      extentZ: 3.0,
      type: ArPlaneType.vertical,
      boundaryPolygon: [
        node.position.translate(dx: -1.75, dy: -1.75),
        node.position.translate(dx: 1.75, dy: -1.75),
        node.position.translate(dx: 1.75, dy: -1.75, dz: 3.0),
        node.position.translate(dx: -1.75, dy: -1.75, dz: 3.0),
      ],
    ));

    if (_lastWalkNode != null) {
      _surveyedEdges.add(NavEdge(
        sourceNodeId: _lastWalkNode!.id,
        targetNodeId: id,
        distanceMeters: _lastWalkNode!.position.distanceTo(node.position),
        transitionType: VerticalTransition.walk,
      ));
    }
    _lastWalkNode = node;
    notifyListeners();
  }

  /// Begins a vertical transition (stairs or elevator) to [targetFloorIndex].
  /// While climbing or descending, corridor waypoint creation is paused so stairs are not drawn as flat floor loops.
  void startVerticalTransition({
    required VerticalTransition transitionType,
    required int targetFloorIndex,
  }) {
    _ensureFloorExists(_activeFloor);
    _ensureFloorExists(targetFloorIndex);

    // Departure node on current floor
    final fromId = 'trans_${transitionType.name}_f${_activeFloor}_${_surveyedNodes.length}';
    final fromNode = NavNode(
      id: fromId,
      name: '${transitionType == VerticalTransition.stairs ? "Stairs" : "Elevator"} to Floor $targetFloorIndex',
      position: Coordinates3D(x: _currentPosition.x, y: _currentPosition.y, z: _activeFloor * 3.6),
      floorIndex: _activeFloor,
      type: transitionType == VerticalTransition.stairs ? NodeType.stairs : NodeType.elevator,
    );
    _surveyedNodes[fromId] = fromNode;

    if (_lastWalkNode != null) {
      _surveyedEdges.add(NavEdge(
        sourceNodeId: _lastWalkNode!.id,
        targetNodeId: fromId,
        distanceMeters: _lastWalkNode!.position.distanceTo(fromNode.position),
        transitionType: VerticalTransition.walk,
      ));
    }

    _stairDepartureNode = fromNode;
    _isTraversingStairs = true;
    _activeTransitionType = transitionType;
    _targetStairFloor = targetFloorIndex;
    notifyListeners();
  }

  /// Finalizes arrival at the landing of the target floor level.
  void completeVerticalTransition() {
    if (!_isTraversingStairs || _targetStairFloor == null || _stairDepartureNode == null) return;

    final targetFloorIndex = _targetStairFloor!;
    final transitionType = _activeTransitionType ?? VerticalTransition.stairs;
    _ensureFloorExists(targetFloorIndex);

    // Landing node on target floor at current physical position
    final toId = 'landing_${transitionType.name}_f${targetFloorIndex}_${_surveyedNodes.length}';
    final toNode = NavNode(
      id: toId,
      name: '${transitionType == VerticalTransition.stairs ? "Stairs" : "Elevator"} from Floor ${_stairDepartureNode!.floorIndex}',
      position: Coordinates3D(x: _currentPosition.x, y: _currentPosition.y, z: targetFloorIndex * 3.6),
      floorIndex: targetFloorIndex,
      type: transitionType == VerticalTransition.stairs ? NodeType.stairs : NodeType.elevator,
    );
    _surveyedNodes[toId] = toNode;

    // Direct 3D Vertical Edge connecting departure to landing
    _surveyedEdges.add(NavEdge(
      sourceNodeId: _stairDepartureNode!.id,
      targetNodeId: toId,
      distanceMeters: (targetFloorIndex - _stairDepartureNode!.floorIndex).abs() * 3.6,
      transitionType: transitionType,
      isWheelchairAccessible: transitionType == VerticalTransition.elevator,
    ));

    // Transition active floor
    _activeFloor = targetFloorIndex;
    _lastWalkNode = toNode;
    _currentPosition = toNode.position;
    _isTraversingStairs = false;
    _targetStairFloor = null;
    _activeTransitionType = null;
    _stairDepartureNode = null;
    notifyListeners();
  }

  /// Backward-compatible vertical transition caller.
  void markVerticalTransition({
    required VerticalTransition transitionType,
    required int targetFloorIndex,
  }) {
    startVerticalTransition(
      transitionType: transitionType,
      targetFloorIndex: targetFloorIndex,
    );
  }

  /// Finalizes the survey and bakes the 3D model into local storage.
  Future<bool> finishSurvey() async {
    try {
      await _arCoreService.stopSession();
      _posSub?.cancel();
      _planeSub?.cancel();
      _trackLivePositionUseCase.stop();

      // Ensure every surveyed floor exists in _floors
      final nodeFloors = _surveyedNodes.values.map((n) => n.floorIndex).toSet();
      for (final f in nodeFloors) {
        _ensureFloorExists(f);
      }
      _floors.sort((a, b) => a.floorIndex.compareTo(b.floorIndex));

      final buildingId = _buildingName.toLowerCase().replaceAll(' ', '_');
      await _canvassBuildingUseCase.execute(
        buildingId: buildingId,
        buildingName: _buildingName,
        floors: _floors,
        nodes: _surveyedNodes,
        edges: _surveyedEdges,
      );

      _isSurveying = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _planeSub?.cancel();
    _arCoreService.stopSession();
    super.dispose();
  }
}
