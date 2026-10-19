import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/services/arcore_canvass_service.dart';
import '../../../domain/models/coordinates_3d.dart';
import '../../../domain/models/floor_level.dart';
import '../../../domain/models/nav_edge.dart';
import '../../../domain/models/nav_node.dart';
import '../../../domain/models/position_estimate.dart';
import '../../../domain/use_cases/canvass_building_use_case.dart';
import '../../../domain/use_cases/track_live_position_use_case.dart';

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
  final List<NavEdge> _surveyedEdges = {};
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
  StreamSubscription<PositionEstimate>? _posSub;
  StreamSubscription<ArPlaneData>? _planeSub;

  /// Whether surveying is actively recording.
  bool get isSurveying => _isSurveying;

  /// The name of the building being surveyed.
  String get buildingName => _buildingName;

  /// The current vertical floor index.
  int get activeFloor => _activeFloor;

  /// The number of waypoints marked so far.
  int get waypointCount => _surveyedNodes.length;

  /// The number of structural planes detected by ARCore.
  int get detectedPlaneCount => _detectedPlaneCount;

  /// The live user coordinates.
  Coordinates3D get currentPosition => _currentPosition;

  /// Starts a new canvassing survey session at doorway [buildingName].
  Future<void> startSurvey(String buildingName) async {
    _buildingName = buildingName;
    _surveyedNodes.clear();
    _surveyedEdges.clear();
    _detectedPlaneCount = 0;
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
      _currentPosition = estimate.position;
      _activeFloor = estimate.floorIndex;

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

  /// Manually drops a named point of interest (e.g. Room, Office, Amenity).
  void markPointOfInterest(String name, NodeType type) {
    final id = 'poi_${_surveyedNodes.length}_${name.replaceAll(' ', '_')}';
    final node = NavNode(
      id: id,
      name: name,
      position: _currentPosition,
      floorIndex: _activeFloor,
      type: type,
    );

    _surveyedNodes[id] = node;
    if (_lastWalkNode != null) {
      _surveyedEdges.add(NavEdge(
        sourceNodeId: _lastWalkNode!.id,
        targetNodeId: id,
        distanceMeters: _lastWalkNode!.position.distanceTo(_currentPosition),
        transitionType: VerticalTransition.walk,
      ));
    }
    _lastWalkNode = node;
    notifyListeners();
  }

  /// Marks a vertical transition (stairs or elevator) to a new floor.
  void markVerticalTransition({
    required VerticalTransition transitionType,
    required int targetFloorIndex,
  }) {
    // Add new floor level if not already present
    if (!_floors.any((f) => f.floorIndex == targetFloorIndex)) {
      _floors.add(FloorLevel(
        floorIndex: targetFloorIndex,
        name: 'Floor $targetFloorIndex',
        baseElevationMeters: targetFloorIndex * 3.6,
        floorHeightMeters: 3.6,
      ));
    }

    final transitionId = 'trans_${transitionType.name}_${_surveyedNodes.length}';
    final node = NavNode(
      id: transitionId,
      name: '${transitionType.name.toUpperCase()} to Floor $targetFloorIndex',
      position: _currentPosition,
      floorIndex: _activeFloor,
      type: transitionType == VerticalTransition.stairs ? NodeType.stairs : NodeType.elevator,
    );

    _surveyedNodes[transitionId] = node;
    if (_lastWalkNode != null) {
      _surveyedEdges.add(NavEdge(
        sourceNodeId: _lastWalkNode!.id,
        targetNodeId: transitionId,
        distanceMeters: _lastWalkNode!.position.distanceTo(_currentPosition),
        transitionType: transitionType,
      ));
    }
    _lastWalkNode = node;
    _activeFloor = targetFloorIndex;
    notifyListeners();
  }

  /// Finalizes the survey and bakes the 3D model into local storage.
  Future<bool> finishSurvey() async {
    try {
      await _arCoreService.stopSession();
      _posSub?.cancel();
      _planeSub?.cancel();
      _trackLivePositionUseCase.stop();

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
