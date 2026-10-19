import 'package:flutter/material.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Displays real-time sensor confidence and calibration indicators.
class SensorStatusBadge extends StatelessWidget {
  /// Creates a sensor status badge.
  const SensorStatusBadge({
    super.key,
    required this.isCalibrated,
    required this.accuracyMeters,
    this.onTapDoorwayCheckin,
  });

  /// Whether the barometer baseline is calibrated to an entrance datum.
  final bool isCalibrated;

  /// The estimated horizontal accuracy radius in meters.
  final double accuracyMeters;

  /// Callback to trigger doorway recalibration.
  final VoidCallback? onTapDoorwayCheckin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapDoorwayCheckin,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCalibrated
                ? AppColors.emeraldGreen.withOpacity(0.15)
                : AppColors.amberWarning.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCalibrated ? AppColors.emeraldGreen : AppColors.amberWarning,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCalibrated ? Icons.door_front_door : Icons.door_front_door_outlined,
                size: 16,
                color: isCalibrated ? AppColors.emeraldGreen : AppColors.amberWarning,
              ),
              const SizedBox(width: 6),
              Text(
                isCalibrated ? 'Doorway: ±${accuracyMeters.toStringAsFixed(1)}m' : 'Calibrate Doorway',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCalibrated ? Colors.white : AppColors.amberWarning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
