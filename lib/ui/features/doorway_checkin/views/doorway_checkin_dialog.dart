import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';
import '../view_models/doorway_checkin_view_model.dart';

/// Modal dialog prompting the user to confirm their exact doorway location.
class DoorwayCheckinDialog extends StatelessWidget {
  /// Creates a doorway check-in dialog.
  const DoorwayCheckinDialog({
    super.key,
    required this.viewModel,
    required this.availableEntrances,
    required this.onCalibrationComplete,
  });

  /// The view model handling the calibration logic.
  final DoorwayCheckinViewModel viewModel;

  /// The list of known entrance nodes for the active building.
  final List<NavNode> availableEntrances;

  /// Callback invoked when doorway check-in succeeds.
  final VoidCallback onCalibrationComplete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Row(
            children: [
              Icon(Icons.door_front_door, color: AppColors.cyanAccent),
              SizedBox(width: 10),
              Text('Doorway Check-in', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you standing directly at the doorway entrance? This sets the building origin and calibrates the barometer completely offline.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (availableEntrances.isNotEmpty) ...[
                const Text(
                  'Select Entrance:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...availableEntrances.map((entrance) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: AppColors.cyanAccent),
                    title: Text(entrance.name, style: const TextStyle(color: Colors.white)),
                    onTap: viewModel.isCalibrating
                        ? null
                        : () async {
                            final success = await viewModel.checkinAtDoorway(
                              entranceId: entrance.id,
                              entranceName: entrance.name,
                              entranceCoordinates: entrance.position,
                            );
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                              onCalibrationComplete();
                            }
                          },
                  );
                }),
              ],
              if (viewModel.isCalibrating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.cyanAccent),
                  ),
                ),
              if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: AppColors.coralRed, fontSize: 13),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: viewModel.isCalibrating
                  ? null
                  : () async {
                      final success = await viewModel.checkinAtDoorway(
                        entranceId: 'main_entrance',
                        entranceName: 'Main Entrance',
                      );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                        onCalibrationComplete();
                      }
                    },
              child: const Text('I am at Doorway Now'),
            ),
          ],
        );
      },
    );
  }
}
