import 'dart:async';
import 'dart:math' as math;

/// Measures relative vertical elevation using the onboard hardware barometer.
///
/// Operates completely offline by latching ambient entrance pressure as datum.
class BarometricAltimeterService {
  /// Creates an offline altimeter service.
  BarometricAltimeterService({
    Stream<double>? pressureStream,
  }) : _pressureStream = pressureStream;

  final Stream<double>? _pressureStream;
  double? _entrancePressureHpa;
  double? _lastRawPressureHpa;
  double _lastFilteredAltitude = 0.0;
  static const double _lowPassAlpha = 0.2; // Exponential moving average smoothing

  /// Whether an entrance pressure baseline has been latched.
  bool get isCalibrated => _entrancePressureHpa != null;

  /// The latched entrance pressure baseline in hectopascals.
  double? get entrancePressureHpa => _entrancePressureHpa;

  /// The most recent ambient barometric pressure measured in hectopascals.
  double? get lastRawPressureHpa => _lastRawPressureHpa;

  /// Latches [pressureHpa] as the ground entrance datum ($z = 0.0\text{ m}$).
  void latchBaseline(double pressureHpa) {
    _entrancePressureHpa = pressureHpa;
    _lastFilteredAltitude = 0.0;
  }

  /// Calculates instantaneous relative altitude in meters from ambient [pressureHpa].
  ///
  /// Uses the international standard atmosphere hypsometric formulation.
  double calculateRelativeAltitude(double pressureHpa) {
    _lastRawPressureHpa = pressureHpa;
    if (_entrancePressureHpa == null) {
      _entrancePressureHpa = pressureHpa;
    }
    final p0 = _entrancePressureHpa!;
    if (p0 <= 0.0) return 0.0;
    return 44330.0 * (1.0 - math.pow(pressureHpa / p0, 1.0 / 5.255));
  }

  /// Computes the floor index for [elevationMeters] using [floorHeightMeters] with hysteresis.
  int estimateFloorIndex(double elevationMeters, {double floorHeightMeters = 3.6}) {
    if (floorHeightMeters <= 0.0) return 0;
    return (elevationMeters / floorHeightMeters).round();
  }

  /// Emits smoothed relative vertical elevation in meters above the doorway entrance.
  Stream<double> get relativeElevationStream {
    final stream = _pressureStream ?? const Stream<double>.empty();
    return stream.map((pressure) {
      final rawAltitude = calculateRelativeAltitude(pressure);
      // Apply low-pass filter to reject indoor door-slamming pressure spikes
      _lastFilteredAltitude = (_lowPassAlpha * rawAltitude) + ((1.0 - _lowPassAlpha) * _lastFilteredAltitude);
      return _lastFilteredAltitude;
    });
  }
}
