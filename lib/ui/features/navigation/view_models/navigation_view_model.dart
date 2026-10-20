import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:compass_3d/domain/models/building_3d_model.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/domain/models/navigation_path.dart';
import 'package:compass_3d/domain/models/position_estimate.dart';
import 'package:compass_3d/domain/repositories/navigation_repository.dart';
import 'package:compass_3d/domain/repositories/sensor_fusion_repository.dart';
import 'package:compass_3d/domain/use_cases/compute_shortest_3d_path_use_case.dart';
import 'package:compass_3d/domain/use_cases/track_live_position_use_case.dart';

/// Manages active multi-floor 3D navigation state and compass calculation.
class NavigationViewModel extends ChangeNotifier {
  /// Creates a navigation view model.
  NavigationViewModel({
    required NavigationRepository navigationRepository,
    required SensorFusionRepository sensorFusionRepository,
    required TrackLivePositionUseCase trackLivePositionUseCase,
    required ComputeShortest3DPathUseCase computeShortestPathUseCase,
  })  : _navigationRepository = navigationRepository,
        _sensorFusionRepository = sensorFusionRepository,
        _trackLivePositionUseCase = trackLivePositionUseCase,
        _computeShortestPathUseCase = computeShortestPathUseCase;

  final NavigationRepository _navigationRepository;
  final SensorFusionRepository _sensorFusionRepository;
  final TrackLivePositionUseCase _trackLivePositionUseCase;
  final ComputeShortest3DPathUseCase _computeShortestPathUseCase;

  StreamSubscription<PositionEstimate>? _posSub;
  Coordinates3D _userPosition = Coordinates3D.zero;
  double _userHeadingRad = 0.0;
  int _currentFloor = 0;
  double _accuracyMeters = 1.0;
  bool _isCalibrated = false;

  NavNode? _targetDestination;
  NavigationPath? _activePath;
  String _currentInstruction = 'Walk forward down the corridor';
  bool _preferElevatorOnly = false;

  /// The active building name.
  String get buildingName => _navigationRepository.activeBuilding?.name ?? 'Building';

  /// The active building model.
  Building3DModel? get activeBuilding => _navigationRepository.activeBuilding;

  /// The estimated 3D position of the user.
  Coordinates3D get userPosition => _userPosition;

  /// The active floor index.
  int get currentFloor => _currentFloor;

  /// The estimated horizontal accuracy in meters.
  double get accuracyMeters => _accuracyMeters;

  /// Whether the user has calibrated at an entrance doorway.
  bool get isCalibrated => _isCalibrated;

  /// The active navigation path, or `null`.
  NavigationPath? get activePath => _activePath;

  /// The selected target destination node.
  NavNode? get targetDestination => _targetDestination;

  /// The active step-by-step navigation instruction.
  String get currentInstruction => _currentInstruction;

  /// Whether routing avoids stairs and prefers elevators.
  bool get preferElevatorOnly => _preferElevatorOnly;

  /// Horizontal compass bearing in degrees toward the next waypoint relative to device orientation.
  double get bearingToTarget {
    final nextWp = _getNextTargetCoordinate();
    if (nextWp == null) return 0.0;

    final dx = nextWp.x - _userPosition.x;
    final dy = nextWp.y - _userPosition.y;
    final absoluteAngleRad = math.atan2(dy, dx);
    final relativeAngleRad = absoluteAngleRad - _userHeadingRad;

    final deg = relativeAngleRad * 180.0 / math.pi;
    return (deg % 360.0 + 360.0) % 360.0;
  }

  /// Vertical pitch inclination angle in degrees toward the next waypoint.
  double get pitchToTarget {
    final nextWp = _getNextTargetCoordinate();
    if (nextWp == null) return 0.0;

    final dz = nextWp.z - _userPosition.z;
    final horizontalDist = _userPosition.horizontalDistanceTo(nextWp);

    if (horizontalDist < 0.2) {
      return dz > 0 ? 90.0 : (dz < 0 ? -90.0 : 0.0);
    }

    final pitchRad = math.atan2(dz, horizontalDist);
    return pitchRad * 180.0 / math.pi;
  }

  /// Distance in meters to the active destination or next waypoint.
  double get distanceToTarget {
    final nextWp = _getNextTargetCoordinate();
    if (nextWp == null) return 0.0;
    return _userPosition.distanceTo(nextWp);
  }

  /// Starts listening to sensor fusion updates.
  void startNavigation() {
    _posSub = _trackLivePositionUseCase.execute().listen((estimate) {
      var currentPos = estimate.position;
      final building = _navigationRepository.activeBuilding;

      // Apply 3D Map Constraint: Landmark Snap & Corridor Wall Bounding
      if (building != null && building.navGraph.nodes.isNotEmpty) {
        currentPos = _applyLayoutConstraint(currentPos, estimate.floorIndex, building);
      }

      _userPosition = currentPos;
      _userHeadingRad = estimate.orientation.azimuthRadians;
      _currentFloor = estimate.floorIndex;
      _accuracyMeters = estimate.horizontalAccuracyMeters;
      _isCalibrated = true;
      _updateInstruction();
      notifyListeners();
    });
  }

  Coordinates3D _applyLayoutConstraint(
    Coordinates3D rawPos,
    int floorIndex,
    Building3DModel building,
  ) {
    final floorNodes = building.navGraph.getNodesForFloor(floorIndex);
    if (floorNodes.isEmpty) return rawPos;

    // 1. Landmark Relocalization: Snap to mapped rooms / doorways / stairwells when in close proximity
    for (final node in floorNodes) {
      final dist = rawPos.horizontalDistanceTo(node.position);
      // If within 1.2m of a named landmark node, snap position and eliminate dead-reckoning drift
      if (dist < 1.2) {
        final snapped = Coordinates3D(x: node.position.x, y: node.position.y, z: rawPos.z);
        _sensorFusionRepository.resetPosition(snapped);
        return snapped;
      }
    }

    // 2. Corridor Wall Bounding: Constrain user position within mapped hallway corridor segments
    final floorEdges = building.navGraph.allEdges.where((e) {
      final s = building.navGraph.nodes[e.sourceNodeId];
      final t = building.navGraph.nodes[e.targetNodeId];
      return s != null && t != null && s.floorIndex == floorIndex && t.floorIndex == floorIndex;
    }).toList();

    if (floorEdges.isEmpty) return rawPos;

    Coordinates3D? bestProjection;
    var minPerpDist = double.infinity;

    for (final edge in floorEdges) {
      final a = building.navGraph.nodes[edge.sourceNodeId]!.position;
      final b = building.navGraph.nodes[edge.targetNodeId]!.position;

      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final segLengthSq = dx * dx + dy * dy;

      if (segLengthSq == 0) continue;

      // Project rawPos onto segment AB
      final t = (((rawPos.x - a.x) * dx + (rawPos.y - a.y) * dy) / segLengthSq).clamp(0.0, 1.0);
      final projX = a.x + t * dx;
      final projY = a.y + t * dy;

      final perpDist = math.sqrt(
        (rawPos.x - projX) * (rawPos.x - projX) + (rawPos.y - projY) * (rawPos.y - projY),
      );

      if (perpDist < minPerpDist) {
        minPerpDist = perpDist;
        bestProjection = Coordinates3D(x: projX, y: projY, z: rawPos.z);
      }
    }

    if (bestProjection != null) {
      const maxCorridorHalfWidth = 1.4; // 1.4 meters (standard corridor half-width)

      // If user drifts outside the physical corridor walls, clamp them back inside
      if (minPerpDist > maxCorridorHalfWidth) {
        final pullFactor = maxCorridorHalfWidth / minPerpDist;
        final clampedX = bestProjection.x + (rawPos.x - bestProjection.x) * pullFactor;
        final clampedY = bestProjection.y + (rawPos.y - bestProjection.y) * pullFactor;
        final clampedPos = Coordinates3D(x: clampedX, y: clampedY, z: rawPos.z);
        _sensorFusionRepository.resetPosition(clampedPos);
        return clampedPos;
      }
    }

    return rawPos;
  }

  /// Selects a target destination node and computes the shortest 3D route.
  void selectDestination(NavNode destination) {
    _targetDestination = destination;
    final building = _navigationRepository.activeBuilding;
    if (building == null) return;

    // Find closest node to current user position on current floor
    final startNode = building.navGraph.findClosestNode(_userPosition, _currentFloor) ??
        building.entranceAnchors.firstOrNull;

    if (startNode != null) {
      try {
        _activePath = _computeShortestPathUseCase.execute(
          graph: building.navGraph,
          startNodeId: startNode.id,
          targetNodeId: destination.id,
          requireElevatorOnly: _preferElevatorOnly,
        );
        _navigationRepository.setActivePath(_activePath);
      } catch (_) {
        _activePath = null;
      }
    }

    _updateInstruction();
    notifyListeners();
  }

  /// Toggles the wheelchair accessibility filter and recomputes route.
  void setPreferElevatorOnly(bool value) {
    _preferElevatorOnly = value;
    if (_targetDestination != null) {
      selectDestination(_targetDestination!);
    }
  }

  Coordinates3D? _getNextTargetCoordinate() {
    if (_activePath != null && _activePath!.isNotEmpty) {
      final next = _activePath!.getNextWaypoint(_userPosition);
      return next?.position ?? _targetDestination?.position;
    }
    return _targetDestination?.position;
  }

  void _updateInstruction() {
    if (_targetDestination == null) {
      _currentInstruction = 'Select a destination room';
      return;
    }

    final targetFloor = _targetDestination!.floorIndex;
    final floorDelta = targetFloor - _currentFloor;

    if (floorDelta > 0) {
      _currentInstruction = 'Ascend to Floor $targetFloor via stairs or lift';
    } else if (floorDelta < 0) {
      _currentInstruction = 'Descend to Floor $targetFloor via stairs or lift';
    } else {
      _currentInstruction = 'Follow arrow to ${_targetDestination!.name}';
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _trackLivePositionUseCase.stop();
    super.dispose();
  }
}
