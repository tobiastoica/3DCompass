import 'dart:math' as math;
import '../../domain/models/coordinates_3d.dart';
import '../../domain/models/orientation_3d.dart';
import '../../domain/models/position_estimate.dart';

/// A 7-state Extended Kalman Filter fusing PDR steps, barometric altitude, and faint GNSS.
///
/// States:
/// [0]: x (horizontal displacement in meters)
/// [1]: y (horizontal displacement in meters)
/// [2]: z (vertical elevation in meters)
/// [3]: vx (horizontal velocity x)
/// [4]: vy (horizontal velocity y)
/// [5]: vz (vertical velocity z)
/// [6]: heading (azimuth in radians)
class ExtendedKalmanFilter {
  /// Creates an EKF initialized at origin.
  ExtendedKalmanFilter() {
    reset(0.0, 0.0, 0.0, 0.0);
  }

  // 7x1 State Vector
  final List<double> _x = List.filled(7, 0.0);

  // Diagonal error covariance approximations (P)
  final List<double> _p = [
    0.5, // var(x)
    0.5, // var(y)
    0.2, // var(z)
    0.1, // var(vx)
    0.1, // var(vy)
    0.1, // var(vz)
    0.05, // var(heading)
  ];

  // Process noise variances (Q)
  static const double _qPdrStep = 0.08; // variance per step displacement
  static const double _qHeading = 0.02; // heading drift variance
  static const double _rBaro = 0.15; // barometer measurement noise variance (m^2)

  /// The current filtered 3D position estimate.
  Coordinates3D get position => Coordinates3D(x: _x[0], y: _x[1], z: _x[2]);

  /// The current filtered heading in radians.
  double get headingRadians => _x[6];

  /// The estimated horizontal standard deviation in meters.
  double get horizontalAccuracyMeters => math.sqrt(math.max(_p[0], _p[1]));

  /// Resets the filter state to [x0], [y0], [z0], and [heading0].
  void reset(double x0, double y0, double z0, double heading0) {
    _x[0] = x0;
    _x[1] = y0;
    _x[2] = z0;
    _x[3] = 0.0;
    _x[4] = 0.0;
    _x[5] = 0.0;
    _x[6] = heading0;

    _p[0] = 0.1;
    _p[1] = 0.1;
    _p[2] = 0.05;
    _p[3] = 0.05;
    _p[4] = 0.05;
    _p[5] = 0.05;
    _p[6] = 0.02;
  }

  /// Predicts the state forward upon a detected PDR step event.
  void predictStep({
    required double stepLengthMeters,
    required double measuredHeadingRadians,
  }) {
    // Process noise allows heading to track turns
    _p[6] += 0.25;
    final kHeading = _p[6] / (_p[6] + 0.08);
    _x[6] = _x[6] + kHeading * (measuredHeadingRadians - _x[6]);
    _p[6] = (1.0 - kHeading) * _p[6];

    // Compute step displacement vector
    final dx = stepLengthMeters * math.cos(_x[6]);
    final dy = stepLengthMeters * math.sin(_x[6]);

    // Position update
    _x[0] += dx;
    _x[1] += dy;

    // Covariance growth
    _p[0] += _qPdrStep;
    _p[1] += _qPdrStep;
  }

  /// Updates vertical state with [measuredAltitudeMeters] from the barometer.
  void updateBarometerAltitude(double measuredAltitudeMeters) {
    _p[2] += 0.3; // Altitude process variance
    final kZ = _p[2] / (_p[2] + _rBaro);
    final residual = measuredAltitudeMeters - _x[2];

    _x[2] += kZ * residual;
    _p[2] = (1.0 - kZ) * _p[2];
  }

  /// Updates horizontal position using a faint GNSS fix with reported [accuracyMeters].
  void updateGpsFix({
    required double localX,
    required double localY,
    required double accuracyMeters,
  }) {
    // Gate out unreliable multipath readings
    if (accuracyMeters > 35.0 || accuracyMeters <= 0.0) return;

    final rGps = accuracyMeters * accuracyMeters;

    // Kalman gain for X
    final kX = _p[0] / (_p[0] + rGps);
    _x[0] += kX * (localX - _x[0]);
    _p[0] = (1.0 - kX) * _p[0];

    // Kalman gain for Y
    final kY = _p[1] / (_p[1] + rGps);
    _x[1] += kY * (localY - _x[1]);
    _p[1] = (1.0 - kY) * _p[1];
  }

  /// Generates a current [PositionEstimate] snapshot.
  PositionEstimate createSnapshot({required int floorIndex, bool isNearEntrance = false}) {
    return PositionEstimate(
      position: position,
      orientation: Orientation3D(
        azimuthRadians: _x[6],
        pitchRadians: 0.0,
        rollRadians: 0.0,
      ),
      floorIndex: floorIndex,
      horizontalAccuracyMeters: horizontalAccuracyMeters,
      timestamp: DateTime.now(),
      isNearEntrance: isNearEntrance,
    );
  }
}
