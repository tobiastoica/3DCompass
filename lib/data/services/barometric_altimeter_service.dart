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

  int _activeFloorIndex = 0;
  final Map<int, double> _floorBaselines = {};

  /// Whether an entrance pressure baseline has been latched.
  bool get isCalibrated => _entrancePressureHpa != null;

  /// The latched entrance pressure baseline in hectopascals.
  double? get entrancePressureHpa => _entrancePressureHpa;

  /// The most recent ambient barometric pressure measured in hectopascals.
  double? get lastRawPressureHpa => _lastRawPressureHpa;

  /// The currently active floor estimated by vertical elevation tracking.
  int get activeFloorIndex => _activeFloorIndex;

  /// Latches [pressureHpa] as the ground entrance datum ($z = 0.0\text{ m}$).
  void latchBaseline(double pressureHpa) {
    _entrancePressureHpa = pressureHpa;
    _floorBaselines[0] = pressureHpa;
    _activeFloorIndex = 0;
    _lastFilteredAltitude = 0.0;
  }

  /// Calculates instantaneous relative altitude in meters from ambient [pressureHpa],
  /// with automatic floor detection (> 2.0m threshold), adaptive floor baseline tracking,
  /// and zero-return calibration.
  double calculateRelativeAltitude(double pressureHpa, {double floorHeightMeters = 3.6}) {
    _lastRawPressureHpa = pressureHpa;
    if (_entrancePressureHpa == null) {
      _entrancePressureHpa = pressureHpa;
      _floorBaselines[0] = pressureHpa;
      _activeFloorIndex = 0;
    }

    final p0 = _entrancePressureHpa!;
    if (p0 <= 0.0) return 0.0;

    // Hypsometric elevation relative to ground entrance datum
    final rawZ = 44330.0 * (1.0 - math.pow(pressureHpa / p0, 1.0 / 5.255));

    // Calculate elevation relative to the currently active floor's expected elevation
    final nominalFloorZ = _activeFloorIndex * floorHeightMeters;
    final deltaFromActiveFloor = rawZ - nominalFloorZ;

    // 1. Automatic Floor Ascent Trigger (> 2.0m rise above active floor)
    if (deltaFromActiveFloor > 2.0) {
      final floorJump = (deltaFromActiveFloor / floorHeightMeters).round().clamp(1, 10);
      _activeFloorIndex += floorJump;
      _floorBaselines[_activeFloorIndex] = pressureHpa;
    }
    // 2. Automatic Floor Descent Trigger (> 2.0m drop below active floor)
    else if (deltaFromActiveFloor < -2.0) {
      final floorDrop = (deltaFromActiveFloor.abs() / floorHeightMeters).round().clamp(1, 10);
      _activeFloorIndex -= floorDrop;

      // When descending back down to Floor 0, update Floor 0's baseline to the current settled
      // pressure to cleanly eliminate any cumulative atmospheric weather drift (zero-return recalibration)
      if (_activeFloorIndex <= 0) {
        _activeFloorIndex = 0;
        _entrancePressureHpa = pressureHpa;
        _floorBaselines[0] = pressureHpa;
      } else {
        _floorBaselines[_activeFloorIndex] = pressureHpa;
      }
    }
    // 3. Steady Horizontal Movement on Current Floor (|deltaFromActiveFloor| <= 1.0m)
    // Slowly update the current floor's pressure baseline with an exponential moving average (1%)
    // to continuously absorb weather and HVAC drift without skewing rapid stair movement.
    else if (deltaFromActiveFloor.abs() <= 1.0) {
      final currentBase = _floorBaselines[_activeFloorIndex] ?? pressureHpa;
      _floorBaselines[_activeFloorIndex] = (0.99 * currentBase) + (0.01 * pressureHpa);
      if (_activeFloorIndex == 0) {
        _entrancePressureHpa = _floorBaselines[0];
      }
    }

    return rawZ;
  }

  /// Computes the floor index for [elevationMeters] using [floorHeightMeters] with hysteresis.
  int estimateFloorIndex(double elevationMeters, {double floorHeightMeters = 3.6}) {
    if (floorHeightMeters <= 0.0) return 0;
    if (_floorBaselines.isNotEmpty) {
      return _activeFloorIndex;
    }
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
