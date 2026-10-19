import '../models/calibration_anchor.dart';
import '../models/coordinates_3d.dart';
import '../repositories/sensor_fusion_repository.dart';

/// Calibrates the building entrance datum and barometer baseline completely offline.
class CalibrateEntranceUseCase {
  /// Creates an entrance calibration interactor.
  const CalibrateEntranceUseCase({
    required SensorFusionRepository sensorFusionRepository,
  }) : _sensorFusionRepository = sensorFusionRepository;

  final SensorFusionRepository _sensorFusionRepository;

  /// Calibrates the sensor fusion coordinate origin at [entranceId].
  ///
  /// Latches the current hardware barometric pressure as the reference baseline
  /// and zeros the spatial coordinate system without requiring any internet access.
  Future<CalibrationAnchor> execute({
    required String entranceId,
    required String entranceName,
    Coordinates3D entranceCoordinates = Coordinates3D.zero,
  }) async {
    final currentPressure = await _sensorFusionRepository.captureCurrentPressure();

    final anchor = CalibrationAnchor(
      entranceId: entranceId,
      entranceName: entranceName,
      entranceCoordinates: entranceCoordinates,
      baselinePressureHpa: currentPressure,
      calibratedAt: DateTime.now(),
    );

    await _sensorFusionRepository.setCalibrationAnchor(anchor);
    _sensorFusionRepository.resetPosition(entranceCoordinates);
    return anchor;
  }
}
