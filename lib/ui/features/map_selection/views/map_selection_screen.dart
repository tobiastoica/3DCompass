import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/building_3d_model.dart';
import 'package:compass_3d/ui/core/constants/app_breakpoints.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';
import '../view_models/map_selection_view_model.dart';

/// Screen displaying preloaded and surveyed building maps with options to navigate or survey.
class MapSelectionScreen extends StatefulWidget {
  /// Creates a map selection screen.
  const MapSelectionScreen({
    super.key,
    required this.viewModel,
    required this.onSelectBuilding,
    required this.onStartSurvey,
    this.onViewLogs,
  });

  /// The view model providing the building list.
  final MapSelectionViewModel viewModel;

  /// Callback when a building is selected for navigation.
  final ValueChanged<Building3DModel> onSelectBuilding;

  /// Callback when user taps to start canvassing a new building.
  final VoidCallback onStartSurvey;

  /// Optional callback to view the device telemetry log path.
  final VoidCallback? onViewLogs;

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadBuildings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          '3D Compass Navigation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.onViewLogs != null)
            IconButton(
              icon: const Icon(Icons.description_outlined, color: AppColors.cyanAccent),
              tooltip: 'Device Telemetry Logs',
              onPressed: widget.onViewLogs,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Buildings',
            onPressed: widget.viewModel.loadBuildings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            if (widget.viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent));
            }

            final buildings = widget.viewModel.buildings;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildCanvassBanner(context),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.map, color: AppColors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Select Building to Navigate',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap any building below to open the 3D Compass & Floor Map:',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (buildings.isEmpty)
                      _buildEmptyState()
                    else
                      ...buildings.map((b) => _buildBuildingCard(b)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvassBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.view_in_ar, color: AppColors.cyanAccent, size: 28),
              SizedBox(width: 10),
              Text(
                'Map a New Building',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Walk around your building with phone in hand. ARCore and hardware sensors automatically map hallways, stairwells, and multi-floor layouts.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            onPressed: widget.onStartSurvey,
            icon: const Icon(Icons.add_a_photo, size: 20),
            label: const Text(
              'Start 3D Survey (Canvassing)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.map_outlined, size: 56, color: Colors.white30),
          SizedBox(height: 12),
          Text(
            'No building maps stored yet.',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Tap "Start 3D Survey" above to survey your first building.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Building3DModel building) {
    return Card(
      color: AppColors.surfaceDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          widget.viewModel.selectBuilding(building);
          widget.onSelectBuilding(building);
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cobaltBlue.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.apartment, color: AppColors.cyanAccent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${building.floors.length} Floors • ${building.navGraph.nodes.length} Waypoints',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: AppColors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: AppColors.cyanAccent, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
