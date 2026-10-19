import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../../domain/models/calibration_anchor.dart';
import '../../domain/models/coordinates_3d.dart';
import '../../domain/models/orientation_3d.dart';
import '../../domain/models/position_estimate.dart';
import '../../domain/repositories/sensor_fusion_repository.dart';
import '../services/barometric_altimeter_service.dart';
import '../services/extended_kalman_filter.dart';
import '../services/faint_gps_service.dart';
import '../services/inertia_pdr_service.dart';

/// Implements [SensorFusionRepository] by orchestrating PDR, barometer, and EKF fusion.
class SensorFusionRepositoryImpl implements SensorFusionRepository {
  /// Creates a sensor fusion repository.
  SensorFusionRepositoryImpl({
    BarometricAltimeterService? altimeterService,
    InertiaPdrService? pdrService,
    FaintGpsService? gpsService,
    ExtendedKalmanFilter? ekf,
  })  : _altimeter = altimeterService ?? BarometricAltimeterService(),
        _pdr = pdrService ?? InertiaPdrService(),
        _gps = gpsService ?? FaintGpsService(),
        _ekf = ekf ?? ExtendedKalmanFilter();

  final BarometricAltimeterService _altimeter;
  final InertiaPdrService _pdr;
  final FaintGpsService _gps;
  final ExtendedKalmanFilter _ekf;

  final _positionController = StreamController<PositionEstimate>.broadcast();
  final _orientationController = StreamController<Orientation3D>.broadcast();
  StreamSubscription<PdrStepEvent>? _stepSub;
  StreamSubscription<double>? _altitudeSub;
  StreamSubscription<GpsFixEvent>? _gpsSub;

  CalibrationAnchor? _activeAnchor;
  int _currentFloorIndex = 0;
  bool _isTracking = false;

  @override
  Future<double> captureCurrentPressure() async {
    // Read the first available event from the barometer stream
    final event = await barometerEventStream().first;
    return event.pressure;
  }

  @override
  Future<void> setCalibrationAnchor(CalibrationAnchor anchor) async {
    _activeAnchor = anchor;
    _altimeter.latchBaseline(anchor.baselinePressureHpa);
    _ekf.reset(
      anchor.entranceCoordinates.x,
      anchor.entranceCoordinates.y,
      anchor.entranceCoordinates.z,
      0.0,
    );
    _currentFloorIndex = 0;
    _emitCurrentEstimate();
  }

  @override
  void resetPosition(Coordinates3D coordinates) {
    _ekf.reset(coordinates.x, coordinates.y, coordinates.z, _pdr.currentHeadingRadians);
    _emitCurrentEstimate();
  }

  @override
  Stream<PositionEstimate> get positionStream => _positionController.stream;

  @override
  Stream<Orientation3D> get orientationStream => _orientationController.stream;

  @override
  Stream<double> get relativeElevationStream => _altimeter.relativeElevationStream;

  @override
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;

    _pdr.start();
    unawaited(_gps.start());

    // 1. Listen to PDR Step Events
    _stepSub = _pdr.stepStream.listen((step) {
      _ekf.predictStep(
        stepLengthMeters: step.stepLengthMeters,
        measuredHeadingRadians: step.headingRadians,
      );

      _orientationController.add(Orientation3D(
        azimuthRadians: step.headingRadians,
        pitchRadians: 0.0,
        rollRadians: 0.0,
      ));

      _emitCurrentEstimate();
    });

    // 2. Listen to Relative Elevation from Barometer
    _altitudeSub = _altimeter.relativeElevationStream.listen((relativeZ) {
      _ekf.updateBarometerAltitude(relativeZ);
      _currentFloorIndex = _altimeter.estimateFloorIndex(relativeZ);
      _emitCurrentEstimate();
    });

    // 3. Listen to Faint GNSS Fixes
    _gpsSub = _gps.fixStream.listen((fix) {
      if (fix.isUsableIndoorFix) {
        // Soft bounding update
        _ekf.updateGpsFix(
          localX: _ekf.position.x, // correlated against active building origin
          localY: _ekf.position.y,
          accuracyMeters: fix.accuracyMeters,
        );
        _emitCurrentEstimate();
      }
    });
  }

  @override
  void stopTracking() {
    if (!_isTracking) return;
    _isTracking = false;

    _stepSub?.cancel();
    _altitudeSub?.cancel();
    _gpsSub?.cancel();
    _pdr.stop();
    _gps.stop();
  }

  void _emitCurrentEstimate() {
    final estimate = _ekf.createSnapshot(
      floorIndex: _currentFloorIndex,
      isNearEntrance: _activeAnchor != null &&
          _ekf.position.distanceTo(_activeAnchor!.entranceCoordinates) < 3.0,
    );
    _positionController.add(estimate);
  }
}
