import 'package:flutter/material.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';
import '../view_models/canvassing_view_model.dart';
import 'widgets/ar_viewfinder_widget.dart';
import 'widgets/canvass_action_sheet.dart';

/// Screen where user surveys a building by walking with ARCore and sensors.
class CanvassingScreen extends StatefulWidget {
  /// Creates a canvassing screen.
  const CanvassingScreen({
    super.key,
    required this.viewModel,
  });

  /// The view model driving the surveying process.
  final CanvassingViewModel viewModel;

  @override
  State<CanvassingScreen> createState() => _CanvassingScreenState();
}

class _CanvassingScreenState extends State<CanvassingScreen> {
  final _buildingNameController = TextEditingController(text: 'Science Hall');

  @override
  void dispose() {
    _buildingNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        if (!widget.viewModel.isSurveying) {
          return _buildStartScreen(context);
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            title: Text(
              'Surveying: ${widget.viewModel.buildingName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            elevation: 2,
          ),
          body: Stack(
            fit: StackFit.expand, // Ensures the Stack fills the entire screen
            children: [
              ArViewfinderWidget(
                detectedPlaneCount: widget.viewModel.detectedPlaneCount,
                isTracking: widget.viewModel.isSurveying,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: CanvassActionSheet(
                    waypointCount: widget.viewModel.waypointCount,
                    activeFloor: widget.viewModel.activeFloor,
                    onMarkRoom: widget.viewModel.markPointOfInterest,
                    onMarkVerticalTransition: (type, floor) =>
                        widget.viewModel.markVerticalTransition(
                      transitionType: type,
                      targetFloorIndex: floor,
                    ),
                    onFinish: () async {
                      final success = await widget.viewModel.finishSurvey();
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.emeraldGreen,
                            content: Text(
                              '🎉 Building 3D layout baked and saved successfully!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Start 3D Building Survey'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [AppColors.cyanAccent, AppColors.cobaltBlue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyanAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.view_in_ar, size: 48, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Survey & Canvass Building',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate an accurate 3D offline map of your building using ARCore, accelerometer & barometer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Instructions Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Easy 3-Step Surveying Guide:',
                      style: TextStyle(
                        color: AppColors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 12),
                    _InstructionStep(
                      number: '1',
                      title: 'Stand at the Entrance Doorway',
                      description: 'Hold phone upright in front of you. This sets the base origin and barometer datum.',
                    ),
                    SizedBox(height: 10),
                    _InstructionStep(
                      number: '2',
                      title: 'Walk Corridors & Halls',
                      description: 'Walk forward at normal walking speed. The app automatically tracks your path.',
                    ),
                    SizedBox(height: 10),
                    _InstructionStep(
                      number: '3',
                      title: 'Mark Landmark Waypoints',
                      description: 'Tap "Add Room" when reaching rooms, or "Stairs" when moving between floors.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _buildingNameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Building Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. Science Complex, Office HQ',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  prefixIcon: const Icon(Icons.apartment, color: AppColors.cyanAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cyanAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  final name = _buildingNameController.text.trim();
                  if (name.isNotEmpty) {
                    widget.viewModel.startSurvey(name);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'Begin Survey at Doorway',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.cobaltBlue,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
