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

/// Detects pedestrian steps and estimates stride lengths and headings using raw IMU streams
/// fused with 3-axis gyroscope angular integration and barometric/magnetometer anchoring.
class InertiaPdrService {
  /// Creates a PDR inertia service.
  InertiaPdrService({
    Stream<UserAccelerometerEvent>? accelerometerStream,
    Stream<AccelerometerEvent>? rawAccelerometerStream,
    Stream<MagnetometerEvent>? magnetometerStream,
    Stream<GyroscopeEvent>? gyroscopeStream,
  })  : _accelerometerStream = accelerometerStream ?? userAccelerometerEventStream(),
        _rawAccelerometerStream = rawAccelerometerStream ?? accelerometerEventStream(),
        _magnetometerStream = magnetometerStream ?? magnetometerEventStream(),
        _gyroscopeStream = gyroscopeStream ?? gyroscopeEventStream();

  final Stream<UserAccelerometerEvent> _accelerometerStream;
  final Stream<AccelerometerEvent> _rawAccelerometerStream;
  final Stream<MagnetometerEvent> _magnetometerStream;
  final Stream<GyroscopeEvent> _gyroscopeStream;

  final _stepController = StreamController<PdrStepEvent>.broadcast();
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<AccelerometerEvent>? _rawAccelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double _currentHeadingRadians = 0.0;
  double _lastMagnitude = 0.0;
  bool _isRising = false;
  double _peakAccel = 0.0;
  double _valleyAccel = 0.0;
  int _lastStepTimestampMs = 0;

  // Normalized upward gravity vector in phone frame (default ~45 deg viewing angle)
  double _upX = 0.0;
  double _upY = 0.7071;
  double _upZ = 0.7071;
  int _lastGyroTimestampMs = 0;
  double _lastOmegaVertical = 0.0;
  bool _hasMagAnchor = false;

  // Weinberg model constant (calibrated for human indoor gait)
  static const double _weinbergK = 0.42;
  static const double _stepThreshold = 1.2; // m/s^2 above resting gravity
  static const int _minStepIntervalMs = 260; // Minimum duration between human steps

  /// The stream of detected pedestrian step displacements.
  Stream<PdrStepEvent> get stepStream => _stepController.stream;

  /// The current heading of the device in radians.
  double get currentHeadingRadians => _currentHeadingRadians;

  /// Starts listening to sensor feeds and analyzing gait kinematics.
  void start() {
    // 1. Raw Accelerometer: Dynamically tracks gravity reaction vector to determine phone orientation
    _rawAccelSub = _rawAccelerometerStream.listen((accel) {
      final norm = math.sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z);
      if (norm > 2.0) {
        _upX = accel.x / norm;
        _upY = accel.y / norm;
        _upZ = accel.z / norm;
      }
    });

    // 2. High-Frequency Gyroscope Integration: Real-time turn tracking with zero magnetic distortion
    _gyroSub = _gyroscopeStream.listen((gyro) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastGyroTimestampMs > 0) {
        final dt = ((now - _lastGyroTimestampMs) / 1000.0).clamp(0.001, 0.1);
        // Project angular velocity onto gravitational vertical axis
        final omegaVertical = gyro.x * _upX + gyro.y * _upY + gyro.z * _upZ;
        _lastOmegaVertical = omegaVertical;

        _currentHeadingRadians += omegaVertical * dt;
        // Normalize into [-pi, pi]
        _currentHeadingRadians = (_currentHeadingRadians + math.pi) % (2 * math.pi) - math.pi;
      }
      _lastGyroTimestampMs = now;
    });

    // 3. Magnetometer: Absolute initial anchor + slow complementary filter during steady walking
    _magSub = _magnetometerStream.listen((mag) {
      // Cartesian horizontal heading from magnetometer (East = 0, North = pi/2)
      final magHeading = math.atan2(mag.y, -mag.x);
      if (!_hasMagAnchor) {
        _currentHeadingRadians = magHeading;
        _hasMagAnchor = true;
      } else {
        // Only blend slowly when user is NOT in the middle of a physical turn to prevent hard-iron pinning
        if (_lastOmegaVertical.abs() < 0.08) {
          var diff = magHeading - _currentHeadingRadians;
          while (diff > math.pi) diff -= 2 * math.pi;
          while (diff < -math.pi) diff += 2 * math.pi;
          _currentHeadingRadians += diff * 0.005;
          _currentHeadingRadians = (_currentHeadingRadians + math.pi) % (2 * math.pi) - math.pi;
        }
      }
    });

    // 4. User Accelerometer: Weinberg step detection & stride length estimation
    _userAccelSub = _accelerometerStream.listen((accel) {
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
    _rawAccelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _userAccelSub?.cancel();
  }

  /// Disposes internal stream controllers.
  void dispose() {
    stop();
    _stepController.close();
  }
}
