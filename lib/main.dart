import 'package:flutter/material.dart';
import 'service_locator.dart';
import 'ui/core/theme/app_colors.dart';
import 'ui/features/canvassing/views/canvassing_screen.dart';
import 'ui/features/doorway_checkin/views/doorway_checkin_dialog.dart';
import 'ui/features/map_selection/views/map_selection_screen.dart';
import 'ui/features/navigation/views/navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.instance.initialize();
  runApp(const Compass3DApp());
}

/// The root application widget for 3D Indoor Compass Navigation.
class Compass3DApp extends StatelessWidget {
  /// Creates the root application widget.
  const Compass3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Compass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        primaryColor: AppColors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyanAccent,
          secondary: AppColors.cobaltBlue,
          surface: AppColors.surfaceDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
        ),
      ),
      home: const _RootNavigator(),
    );
  }
}

class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    final sl = ServiceLocator.instance;

    return MapSelectionScreen(
      viewModel: sl.createMapSelectionViewModel(),
      onSelectBuilding: (building) {
        final navVm = sl.createNavigationViewModel();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NavigationScreen(
              viewModel: navVm,
              doorwayCheckinDialogBuilder: (ctx, onComplete) {
                return DoorwayCheckinDialog(
                  viewModel: sl.createDoorwayCheckinViewModel(),
                  availableEntrances: building.entranceAnchors,
                  onCalibrationComplete: onComplete,
                );
              },
            ),
          ),
        );
      },
      onStartSurvey: () {
        final canvassVm = sl.createCanvassingViewModel();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CanvassingScreen(viewModel: canvassVm),
          ),
        );
      },
      onViewLogs: () {
        final logPath = sl.logger.activeLogFilePath ?? '/storage/emulated/0/Download/3d_compass_log.txt';
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Row(
              children: [
                Icon(Icons.description, color: AppColors.cyanAccent),
                SizedBox(width: 10),
                Text('Device Telemetry Logs', style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Continuous telemetry is saved directly in the mobile Downloads directory for real-time inspection:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    logPath,
                    style: const TextStyle(
                      color: AppColors.cyanAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Doorway baseline calibrations\n'
                  '• PDR step lengths & heading angles\n'
                  '• Barometer pressure & floor tracking\n'
                  '• Faint GNSS fixes & EKF covariance\n'
                  '• 3D A* computed paths & waypoints',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: AppColors.cyanAccent)),
              ),
            ],
          ),
        );
      },
    );
  }
}
