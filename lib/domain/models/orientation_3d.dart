import 'dart:math' as math;

/// The three-dimensional attitude of the device in space.
class Orientation3D {
  /// Creates a three-dimensional orientation.
  const Orientation3D({
    required this.azimuthRadians,
    required this.pitchRadians,
    required this.rollRadians,
  });

  /// The horizontal compass azimuth angle in radians relative to True North.
  final double azimuthRadians;

  /// The vertical tilt pitch angle in radians.
  final double pitchRadians;

  /// The lateral roll angle in radians.
  final double rollRadians;

  /// The azimuth in degrees ranging from 0 to 360.
  double get azimuthDegrees {
    final deg = azimuthRadians * 180.0 / math.pi;
    return (deg % 360.0 + 360.0) % 360.0;
  }

  /// The pitch in degrees ranging from -90 to +90.
  double get pitchDegrees => pitchRadians * 180.0 / math.pi;

  /// The roll in degrees ranging from -180 to +180.
  double get rollDegrees => rollRadians * 180.0 / math.pi;

  /// A neutral zero orientation pointing north and lying flat.
  static const Orientation3D neutral = Orientation3D(
    azimuthRadians: 0.0,
    pitchRadians: 0.0,
    rollRadians: 0.0,
  );
}
