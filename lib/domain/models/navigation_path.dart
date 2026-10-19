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

  /// Identifies the next waypoint along the path from [currentPosition].
  NavNode? getNextWaypoint(Coordinates3D currentPosition, {double thresholdMeters = 2.0}) {
    for (final wp in _waypoints) {
      if (currentPosition.distanceTo(wp.position) > thresholdMeters) {
        return wp;
      }
    }
    return destinationNode;
  }
}
