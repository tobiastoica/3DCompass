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
/// fused with 3-axis gyroscope angular integration, 3D tilt-compensated magnetometer anchoring,
/// and camera-decoupled walking heading filtering.
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
  double _walkingHeadingRadians = 0.0;
  double _lastMagnitude = 0.0;
  bool _isRising = false;
  double _peakAccel = 0.0;
  double _valleyAccel = 0.0;
  int _lastStepTimestampMs = 0;

  // Normalized upward gravity vector in phone frame
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

  /// The current instantaneous camera heading of the device in radians.
  double get currentHeadingRadians => _currentHeadingRadians;

  /// The smoothed body walking heading in radians (decoupled from camera scanning rotations).
  double get walkingHeadingRadians => _walkingHeadingRadians;

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

        // Smoothly propagate sustained turns to walking heading while filtering quick camera panning
        var headingDiff = _currentHeadingRadians - _walkingHeadingRadians;
        while (headingDiff > math.pi) headingDiff -= 2 * math.pi;
        while (headingDiff < -math.pi) headingDiff += 2 * math.pi;

        if (headingDiff.abs() > 0.35) {
          // Sustained physical corner turn (e.g. 90 deg into hallway/room)
          _walkingHeadingRadians += headingDiff * 0.30;
        } else {
          // Gentle tracking during straight walking (rejection of wall scanning wobble)
          _walkingHeadingRadians += headingDiff * 0.06;
        }
        _walkingHeadingRadians = (_walkingHeadingRadians + math.pi) % (2 * math.pi) - math.pi;
      }
      _lastGyroTimestampMs = now;
    });

    // 3. Magnetometer: True 3D Tilt-Compensated Horizontal Compass Heading
    _magSub = _magnetometerStream.listen((mag) {
      // East vector is perpendicular to both magnetometer vector and gravity vector
      final eX = mag.y * _upZ - mag.z * _upY;
      final eY = mag.z * _upX - mag.x * _upZ;
      final eZ = mag.x * _upY - mag.y * _upX;
      final eNorm = math.sqrt(eX * eX + eY * eY + eZ * eZ);

      if (eNorm > 1e-4) {
        final eastX = eX / eNorm;
        final eastY = eY / eNorm;
        final eastZ = eZ / eNorm;

        // North vector lies in horizontal ground plane pointing magnetic north
        final northX = _upY * eastZ - _upZ * eastY;
        final northY = _upZ * eastX - _upX * eastZ;
        final northZ = _upX * eastY - _upY * eastX;

        // Horizontal forward vector in device frame (independent of flat vs upright posture)
        final fwdY = _upZ;
        final fwdZ = -_upY;

        final dotEast = fwdY * eastY + fwdZ * eastZ;
        final dotNorth = fwdY * northY + fwdZ * northZ;

        final magHeading = math.atan2(dotNorth, dotEast);

        if (!_hasMagAnchor) {
          _currentHeadingRadians = magHeading;
          _walkingHeadingRadians = magHeading;
          _hasMagAnchor = true;
        } else {
          // Slow continuous anchor drift correction when device is not turning rapidly
          if (_lastOmegaVertical.abs() < 0.08) {
            var diff = magHeading - _currentHeadingRadians;
            while (diff > math.pi) diff -= 2 * math.pi;
            while (diff < -math.pi) diff += 2 * math.pi;
            _currentHeadingRadians += diff * 0.005;
            _currentHeadingRadians = (_currentHeadingRadians + math.pi) % (2 * math.pi) - math.pi;
          }
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

            // Steps propagate along the smoothed body walking heading
            _stepController.add(PdrStepEvent(
              stepLengthMeters: clampedStride,
              headingRadians: _walkingHeadingRadians,
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
