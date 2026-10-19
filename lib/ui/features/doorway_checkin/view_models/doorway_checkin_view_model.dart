import 'package:flutter/foundation.dart';
import '../../../domain/models/calibration_anchor.dart';
import '../../../domain/models/coordinates_3d.dart';
import '../../../domain/use_cases/calibrate_entrance_use_case.dart';

/// Manages doorway check-in and offline barometric datum calibration state.
class DoorwayCheckinViewModel extends ChangeNotifier {
  /// Creates a doorway check-in view model.
  DoorwayCheckinViewModel({
    required CalibrateEntranceUseCase calibrateEntranceUseCase,
  }) : _calibrateEntranceUseCase = calibrateEntranceUseCase;

  final CalibrateEntranceUseCase _calibrateEntranceUseCase;

  bool _isCalibrating = false;
  CalibrationAnchor? _lastAnchor;
  String? _errorMessage;

  /// Whether calibration is actively processing.
  bool get isCalibrating => _isCalibrating;

  /// The most recent calibration anchor recorded.
  CalibrationAnchor? get lastAnchor => _lastAnchor;

  /// An error message if calibration fails, or `null`.
  String? get errorMessage => _errorMessage;

  /// Calibrates the entrance datum offline at the current doorway.
  Future<bool> checkinAtDoorway({
    required String entranceId,
    required String entranceName,
    Coordinates3D entranceCoordinates = Coordinates3D.zero,
  }) async {
    _isCalibrating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastAnchor = await _calibrateEntranceUseCase.execute(
        entranceId: entranceId,
        entranceName: entranceName,
        entranceCoordinates: entranceCoordinates,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to calibrate entrance: $e';
      return false;
    } finally {
      _isCalibrating = false;
      notifyListeners();
    }
  }
}
