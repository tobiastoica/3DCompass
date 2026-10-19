import 'dart:math' as math;

/// A three-dimensional spatial coordinate in meters relative to a building datum.
class Coordinates3D {
  /// Creates a three-dimensional coordinate.
  const Coordinates3D({
    required this.x,
    required this.y,
    required this.z,
  });

  /// The horizontal east-west displacement in meters.
  final double x;

  /// The horizontal north-south displacement in meters.
  final double y;

  /// The vertical elevation above the entrance datum in meters.
  final double z;

  /// The origin point representing the zero coordinate datum.
  static const Coordinates3D zero = Coordinates3D(x: 0.0, y: 0.0, z: 0.0);

  /// Computes the Euclidean distance to [other] in 3D space.
  double distanceTo(Coordinates3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Computes the horizontal 2D Euclidean distance to [other] ignoring elevation.
  double horizontalDistanceTo(Coordinates3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns a new coordinate translated by [dx], [dy], and [dz].
  Coordinates3D translate({
    double dx = 0.0,
    double dy = 0.0,
    double dz = 0.0,
  }) {
    return Coordinates3D(
      x: x + dx,
      y: y + dy,
      z: z + dz,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coordinates3D &&
        other.x == x &&
        other.y == y &&
        other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Coordinates3D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}
