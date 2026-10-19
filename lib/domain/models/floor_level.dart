/// Represents a specific floor or story within a multi-layer building.
class FloorLevel {
  /// Creates a floor level descriptor.
  const FloorLevel({
    required this.floorIndex,
    required this.name,
    required this.baseElevationMeters,
    required this.floorHeightMeters,
  });

  /// The integer index of the floor (e.g. 0 for ground, 1 for first floor, -1 for basement).
  final int floorIndex;

  /// The human-readable name of the floor (e.g. "Ground Floor", "Level 2").
  final String name;

  /// The base elevation in meters above the ground entrance datum.
  final double baseElevationMeters;

  /// The vertical clearance height of the floor in meters.
  final double floorHeightMeters;

  /// The ceiling elevation in meters above the ground entrance datum.
  double get ceilingElevationMeters => baseElevationMeters + floorHeightMeters;

  /// Whether the specified elevation in meters falls within this floor's boundaries.
  bool containsElevation(double elevationMeters) {
    return elevationMeters >= baseElevationMeters &&
        elevationMeters < ceilingElevationMeters;
  }
}
