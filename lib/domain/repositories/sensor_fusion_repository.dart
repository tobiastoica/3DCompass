import '../models/calibration_anchor.dart';
import '../models/coordinates_3d.dart';
import '../models/orientation_3d.dart';
import '../models/position_estimate.dart';

/// Contract for real-time sensor fusion and indoor positioning estimation.
abstract class SensorFusionRepository {
  /// Captures the current instantaneous ambient atmospheric pressure in hectopascals.
  Future<double> captureCurrentPressure();

  /// Establishes the ground-truth coordinate datum and barometer baseline at [anchor].
  Future<void> setCalibrationAnchor(CalibrationAnchor anchor);

  /// Resets the current estimated position to [coordinates] and heading to zero.
  void resetPosition(Coordinates3D coordinates);

  /// Stream of continuous 3D fused position estimates.
  Stream<PositionEstimate> get positionStream;

  /// Stream of real-time 3D device orientation updates.
  Stream<Orientation3D> get orientationStream;

  /// Stream of relative vertical elevation in meters above the doorway entrance.
  Stream<double> get relativeElevationStream;

  /// Starts the sensor ingestion pipeline.
  void startTracking();

  /// Stops the sensor ingestion pipeline to conserve battery.
  void stopTracking();
}
