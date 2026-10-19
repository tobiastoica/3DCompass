/// The physical transition type linking two navigation nodes.
enum VerticalTransition {
  /// A standard horizontal walking path on the same floor.
  walk,

  /// A staircase connecting different floor elevations.
  stairs,

  /// An elevator shaft transition between floors.
  elevator,

  /// An incline or ramp transition.
  ramp,
}

/// A traversable segment connecting two navigation waypoints in 3D space.
class NavEdge {
  /// Creates a navigation edge.
  const NavEdge({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.distanceMeters,
    this.transitionType = VerticalTransition.walk,
    this.isWheelchairAccessible = true,
  });

  /// The identifier of the origin node.
  final String sourceNodeId;

  /// The identifier of the destination node.
  final String targetNodeId;

  /// The physical walking or traversal distance in meters.
  final double distanceMeters;

  /// The transition mode between the connected nodes.
  final VerticalTransition transitionType;

  /// Whether this edge is accessible without using stairs.
  final bool isWheelchairAccessible;

  @override
  String toString() => 'NavEdge($sourceNodeId -> $targetNodeId, dist: ${distanceMeters.toStringAsFixed(1)}m, type: $transitionType)';
}
