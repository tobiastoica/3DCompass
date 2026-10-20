import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:compass_3d/data/services/arcore_canvass_service.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/domain/models/position_estimate.dart';
import 'package:compass_3d/domain/use_cases/canvass_building_use_case.dart';
import 'package:compass_3d/domain/use_cases/track_live_position_use_case.dart';

/// Manages the real-time building surveying and ARCore canvassing workflow.
class CanvassingViewModel extends ChangeNotifier {
  /// Creates a canvassing view model.
  CanvassingViewModel({
    required CanvassBuildingUseCase canvassBuildingUseCase,
    required TrackLivePositionUseCase trackLivePositionUseCase,
    required ArCoreCanvassService arCoreService,
  })  : _canvassBuildingUseCase = canvassBuildingUseCase,
        _trackLivePositionUseCase = trackLivePositionUseCase,
        _arCoreService = arCoreService;

  final CanvassBuildingUseCase _canvassBuildingUseCase;
  final TrackLivePositionUseCase _trackLivePositionUseCase;
  final ArCoreCanvassService _arCoreService;

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

  /// Starts a new canvassing survey session at doorway [buildingName].
  Future<void> startSurvey(String buildingName, {int initialFloorCount = 1}) async {
    _buildingName = buildingName;
    _surveyedNodes.clear();
    _surveyedEdges.clear();
    _detectedPlaneCount = 0;
    _stepCount = 0;
    _activeFloor = 0;

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

    // Listen to live movement
    _posSub = _trackLivePositionUseCase.execute().listen((estimate) {
      _stepCount++;
      // In survey mode, horizontal tracking comes from PDR, while activeFloor stays pinned to user selection
      _currentPosition = Coordinates3D(
        estimate.position.x,
        estimate.position.y,
        _activeFloor * 3.6,
      );

      // Automatically place corridor waypoints every 3 meters
      if (_lastWalkNode != null &&
          _lastWalkNode!.position.distanceTo(_currentPosition) >= 3.0) {
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
          distanceMeters: _lastWalkNode!.position.distanceTo(_currentPosition),
          transitionType: VerticalTransition.walk,
        ));
        _lastWalkNode = newNode;
        notifyListeners();
      }
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
    _currentPosition = Coordinates3D(_currentPosition.x, _currentPosition.y, floorIndex * 3.6);
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
      position: Coordinates3D(_currentPosition.x, _currentPosition.y, _activeFloor * 3.6),
      floorIndex: _activeFloor,
      type: type,
    );

    _surveyedNodes[id] = node;
    _ensureFloorExists(_activeFloor);

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

  /// Marks a vertical transition (stairs or elevator) connecting current floor to [targetFloorIndex].
  void markVerticalTransition({
    required VerticalTransition transitionType,
    required int targetFloorIndex,
  }) {
    _ensureFloorExists(_activeFloor);
    _ensureFloorExists(targetFloorIndex);

    // 1. Departure node on current floor
    final fromId = 'trans_${transitionType.name}_f${_activeFloor}_${_surveyedNodes.length}';
    final fromNode = NavNode(
      id: fromId,
      name: '${transitionType == VerticalTransition.stairs ? "Stairs" : "Elevator"} to Floor $targetFloorIndex',
      position: Coordinates3D(_currentPosition.x, _currentPosition.y, _activeFloor * 3.6),
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

    // 2. Landing node on target floor
    final toId = 'landing_${transitionType.name}_f${targetFloorIndex}_${_surveyedNodes.length}';
    final toNode = NavNode(
      id: toId,
      name: '${transitionType == VerticalTransition.stairs ? "Stairs" : "Elevator"} from Floor $_activeFloor',
      position: Coordinates3D(_currentPosition.x, _currentPosition.y, targetFloorIndex * 3.6),
      floorIndex: targetFloorIndex,
      type: transitionType == VerticalTransition.stairs ? NodeType.stairs : NodeType.elevator,
    );
    _surveyedNodes[toId] = toNode;

    // 3. 3D Vertical Edge connecting both floors
    _surveyedEdges.add(NavEdge(
      sourceNodeId: fromId,
      targetNodeId: toId,
      distanceMeters: (targetFloorIndex - _activeFloor).abs() * 3.6,
      transitionType: transitionType,
      isWheelchairAccessible: transitionType == VerticalTransition.elevator,
    ));

    // Transition surveyor state to target floor
    _activeFloor = targetFloorIndex;
    _lastWalkNode = toNode;
    _currentPosition = toNode.position;
    notifyListeners();
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
