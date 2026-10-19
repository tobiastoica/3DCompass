import '../models/position_estimate.dart';
import '../repositories/sensor_fusion_repository.dart';

/// Provides continuous streams of sensor-fused indoor positioning.
class TrackLivePositionUseCase {
  /// Creates a live position tracking interactor.
  const TrackLivePositionUseCase({
    required SensorFusionRepository sensorFusionRepository,
  }) : _sensorFusionRepository = sensorFusionRepository;

  final SensorFusionRepository _sensorFusionRepository;

  /// Starts the tracking sensor pipeline and returns the real-time position stream.
  Stream<PositionEstimate> execute() {
    _sensorFusionRepository.startTracking();
    return _sensorFusionRepository.positionStream;
  }

  /// Pauses the sensor tracking pipeline to conserve battery.
  void stop() {
    _sensorFusionRepository.stopTracking();
  }
}
