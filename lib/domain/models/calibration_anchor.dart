import 'coordinates_3d.dart';

/// The reference calibration baseline established when entering a building.
class CalibrationAnchor {
  /// Creates a calibration anchor baseline.
  const CalibrationAnchor({
    required this.entranceId,
    required this.entranceName,
    required this.entranceCoordinates,
    required this.baselinePressureHpa,
    required this.calibratedAt,
  });

  /// The unique identifier of the doorway entrance.
  final String entranceId;

  /// The human-readable name of the entrance (e.g. "Main North Doorway").
  final String entranceName;

  /// The spatial position of the doorway in the building coordinate frame.
  final Coordinates3D entranceCoordinates;

  /// The ambient atmospheric pressure measured at the entrance in hectopascals.
  final double baselinePressureHpa;

  /// The timestamp when the calibration was recorded.
  final DateTime calibratedAt;
}
