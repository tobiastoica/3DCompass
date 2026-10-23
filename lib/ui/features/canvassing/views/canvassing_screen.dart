import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';
import '../view_models/canvassing_view_model.dart';
import 'widgets/ar_viewfinder_widget.dart';
import 'widgets/canvass_action_sheet.dart';

/// Screen where user surveys a building by walking with camera, AR HUD, and sensors.
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
  int _initialFloorCount = 4; // Default to 4 floors as user needs multi-floor

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
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.85),
            title: Text(
              'Surveying: ${widget.viewModel.buildingName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            elevation: 0,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Camera Preview & AR Viewfinder
              ArViewfinderWidget(
                detectedPlaneCount: widget.viewModel.detectedPlaneCount,
                isTracking: widget.viewModel.isSurveying,
                headingDegrees: widget.viewModel.currentHeadingDegrees,
                activeFloor: widget.viewModel.activeFloor,
                stepCount: widget.viewModel.stepCount,
              ),

              // 2. Active Stair / Elevator Traversing Banner
              if (widget.viewModel.isTraversingStairs)
                Positioned(
                  bottom: 210,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFB45309), // Amber 700
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.stairs, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.viewModel.activeTransitionType == VerticalTransition.stairs ? "Climbing Stairs" : "In Elevator"} to Floor ${widget.viewModel.stairTargetFloor}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const Text(
                                  'Walk stairs. Tap "Arrived" at landing.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => widget.viewModel.completeVerticalTransition(),
                            child: const Text('Arrived', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Bottom Canvass Action Sheet with Floor Switcher
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: CanvassActionSheet(
                    floors: widget.viewModel.floors,
                    activeFloor: widget.viewModel.activeFloor,
                    waypointCount: widget.viewModel.waypointCount,
                    onSelectFloor: widget.viewModel.selectFloor,
                    onAddFloor: widget.viewModel.addFloor,
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
                              '🎉 Building 3D multi-floor layout saved successfully!',
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
                  child: const Icon(Icons.camera_alt, size: 48, color: Colors.black),
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
                'Uses live camera preview, motion sensors, and multi-floor tracking to map building rooms and hallways.',
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
                      '📋 Quick Surveying Instructions:',
                      style: TextStyle(
                        color: AppColors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 12),
                    _InstructionStep(
                      number: '1',
                      title: 'Live Camera View',
                      description: 'Point phone camera along corridors while walking.',
                    ),
                    SizedBox(height: 10),
                    _InstructionStep(
                      number: '2',
                      title: 'Select Active Floor',
                      description: 'Use the floor bar at the bottom to choose which floor you are on.',
                    ),
                    SizedBox(height: 10),
                    _InstructionStep(
                      number: '3',
                      title: 'Mark Rooms & Stairs',
                      description: 'Tap "Add Room" at doors, or "Stairs / Lift" when moving up/down.',
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
              const SizedBox(height: 18),

              // Floor Count Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.layers, color: AppColors.cyanAccent, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Number of Floors:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Pre-configures floor levels', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    DropdownButton<int>(
                      value: _initialFloorCount,
                      dropdownColor: AppColors.surfaceDark,
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      items: [1, 2, 3, 4, 5, 6, 7, 8].map((count) {
                        return DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count Floors'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _initialFloorCount = val);
                        }
                      },
                    ),
                  ],
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
                    widget.viewModel.startSurvey(name, initialFloorCount: _initialFloorCount);
                  }
                },
                icon: const Icon(Icons.camera_alt, size: 24),
                label: const Text(
                  'Begin Camera Survey at Doorway',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
