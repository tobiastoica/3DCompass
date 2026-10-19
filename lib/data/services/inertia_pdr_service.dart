import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

/// Represents a detected pedestrian step event.
class PdrStepEvent {
  /// Creates a PDR step event.
  const PdrStepEvent({
    required this.stepLengthMeters,
    required this.headingRadians,
    required this.timestamp,
  });

  /// The estimated length of the stride in meters.
  final double stepLengthMeters;

  /// The compass azimuth heading at the instant of the step in radians.
  final double headingRadians;

  /// The timestamp when the step was detected.
  final DateTime timestamp;

  /// Computes the horizontal displacement delta vector $[dx, dy]$.
  (double dx, double dy) get displacementDelta {
    return (
      stepLengthMeters * math.cos(headingRadians),
      stepLengthMeters * math.sin(headingRadians),
    );
  }
}

/// Detects pedestrian steps and estimates stride lengths and headings using raw IMU streams.
class InertiaPdrService {
  /// Creates a PDR inertia service.
  InertiaPdrService({
    Stream<UserAccelerometerEvent>? accelerometerStream,
    Stream<MagnetometerEvent>? magnetometerStream,
  })  : _accelerometerStream = accelerometerStream ?? userAccelerometerEventStream(),
        _magnetometerStream = magnetometerStream ?? magnetometerEventStream();

  final Stream<UserAccelerometerEvent> _accelerometerStream;
  final Stream<MagnetometerEvent> _magnetometerStream;

  final _stepController = StreamController<PdrStepEvent>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _currentHeadingRadians = 0.0;
  double _lastMagnitude = 0.0;
  bool _isRising = false;
  double _peakAccel = 0.0;
  double _valleyAccel = 0.0;
  int _lastStepTimestampMs = 0;

  // Weinberg model constant (typically calibrated between 0.38 and 0.45)
  static const double _weinbergK = 0.42;
  static const double _stepThreshold = 1.2; // m/s^2 above resting gravity
  static const int _minStepIntervalMs = 260; // Minimum duration between human steps

  /// The stream of detected pedestrian step displacements.
  Stream<PdrStepEvent> get stepStream => _stepController.stream;

  /// The current heading of the device in radians.
  double get currentHeadingRadians => _currentHeadingRadians;

  /// Starts listening to sensor feeds and analyzing gait kinematics.
  void start() {
    _magSub = _magnetometerStream.listen((mag) {
      // Approximate horizontal heading from magnetometer
      _currentHeadingRadians = math.atan2(mag.y, mag.x);
    });

    _accelSub = _accelerometerStream.listen((accel) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final magnitude = math.sqrt(
        accel.x * accel.x + accel.y * accel.y + accel.z * accel.z,
      );

      // Detect peak / valley transitions
      if (magnitude > _lastMagnitude) {
        if (!_isRising) {
          _isRising = true;
          _valleyAccel = _lastMagnitude;
        }
      } else if (magnitude < _lastMagnitude) {
        if (_isRising) {
          _isRising = false;
          _peakAccel = _lastMagnitude;

          // Check if peak exceeds dynamic threshold and minimum step interval has elapsed
          if (_peakAccel > _stepThreshold && (now - _lastStepTimestampMs) > _minStepIntervalMs) {
            _lastStepTimestampMs = now;
            final bounce = math.max(0.1, _peakAccel - _valleyAccel);
            final strideLength = _weinbergK * math.pow(bounce, 0.25);

            // Clamp stride length between realistic bounds (0.35m - 1.20m)
            final clampedStride = strideLength.clamp(0.35, 1.20).toDouble();

            _stepController.add(PdrStepEvent(
              stepLengthMeters: clampedStride,
              headingRadians: _currentHeadingRadians,
              timestamp: DateTime.fromMillisecondsSinceEpoch(now),
            ));
          }
        }
      }

      _lastMagnitude = magnitude;
    });
  }

  /// Stops sensor subscriptions and releases resources.
  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
  }

  /// Disposes internal stream controllers.
  void dispose() {
    stop();
    _stepController.close();
  }
}
