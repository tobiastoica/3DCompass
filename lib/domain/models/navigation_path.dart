import 'coordinates_3d.dart';
import 'nav_node.dart';

/// An ordered sequence of waypoints representing an optimal navigation path.
class NavigationPath {
  /// Creates a navigation path.
  NavigationPath({required List<NavNode> waypoints})
      : _waypoints = List.unmodifiable(waypoints);

  final List<NavNode> _waypoints;

  /// The ordered sequence of waypoints along the route.
  List<NavNode> get waypoints => _waypoints;

  /// Whether the path contains at least one waypoint.
  bool get isNotEmpty => _waypoints.isNotEmpty;

  /// Whether the path contains zero waypoints.
  bool get isEmpty => _waypoints.isEmpty;

  /// The first waypoint on the path.
  NavNode? get startNode => _waypoints.isNotEmpty ? _waypoints.first : null;

  /// The final destination waypoint on the path.
  NavNode? get destinationNode => _waypoints.isNotEmpty ? _waypoints.last : null;

  /// Computes the total Euclidean distance of the path across all waypoints in meters.
  double get totalDistanceMeters {
    if (_waypoints.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < _waypoints.length - 1; i++) {
      total += _waypoints[i].position.distanceTo(_waypoints[i + 1].position);
    }
    return total;
  }

  /// Identifies the next forward waypoint along the path from [currentPosition].
  NavNode? getNextWaypoint(Coordinates3D currentPosition, {double thresholdMeters = 2.5}) {
    if (_waypoints.isEmpty) return null;
    if (_waypoints.length == 1) return _waypoints.first;

    // 1. Find the path segment closest to currentPosition
    var bestSegIndex = 0;
    var minSegDist = double.infinity;

    for (var i = 0; i < _waypoints.length - 1; i++) {
      final a = _waypoints[i].position;
      final b = _waypoints[i + 1].position;
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final dz = b.z - a.z;
      final segLenSq = dx * dx + dy * dy + dz * dz;

      if (segLenSq == 0) continue;

      final t = (((currentPosition.x - a.x) * dx +
                  (currentPosition.y - a.y) * dy +
                  (currentPosition.z - a.z) * dz) / segLenSq).clamp(0.0, 1.0);

      final px = a.x + t * dx;
      final py = a.y + t * dy;
      final pz = a.z + t * dz;

      final d = currentPosition.distanceTo(Coordinates3D(x: px, y: py, z: pz));
      if (d < minSegDist) {
        minSegDist = d;
        bestSegIndex = i;
      }
    }

    // Target the end of the current active segment
    var targetIndex = bestSegIndex + 1;

    // If already within threshold of that waypoint and not at destination, advance forward
    if (targetIndex < _waypoints.length - 1) {
      if (currentPosition.distanceTo(_waypoints[targetIndex].position) < thresholdMeters) {
        targetIndex++;
      }
    }

    return _waypoints[targetIndex];
  }
}
