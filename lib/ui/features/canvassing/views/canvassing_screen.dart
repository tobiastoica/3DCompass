import 'package:flutter/material.dart';
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
          appBar: AppBar(
            title: Text('Canvassing: ${widget.viewModel.buildingName}'),
          ),
          body: Stack(
            children: [
              ArViewfinderWidget(
                detectedPlaneCount: widget.viewModel.detectedPlaneCount,
                isTracking: widget.viewModel.isSurveying,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
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
                        const SnackBar(content: Text('Building 3D layout saved successfully!')),
                      );
                      Navigator.of(context).pop();
                    }
                  },
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
      appBar: AppBar(title: const Text('Start 3D Building Survey')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.explore, size: 72, color: Colors.cyanAccent),
            const SizedBox(height: 16),
            const Text(
              'Survey & Canvass Building',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Stand at the entrance doorway, hold the phone in front of you, and walk through corridors, stairwells, and rooms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _buildingNameController,
              decoration: const InputDecoration(
                labelText: 'Building Name',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                final name = _buildingNameController.text.trim();
                if (name.isNotEmpty) {
                  widget.viewModel.startSurvey(name);
                }
              },
              child: const Text('Begin Survey at Doorway'),
            ),
          ],
        ),
      ),
    );
  }
}
