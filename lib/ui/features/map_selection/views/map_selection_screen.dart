import 'package:flutter/material.dart';
import '../../../domain/models/building_3d_model.dart';
import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
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
      appBar: AppBar(
        title: const Text('3D Compass Buildings'),
        actions: [
          if (widget.onViewLogs != null)
            IconButton(
              icon: const Icon(Icons.description_outlined, color: AppColors.cyanAccent),
              tooltip: 'Device Telemetry Logs',
              onPressed: widget.onViewLogs,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.viewModel.loadBuildings,
          ),
        ],
      ),
      body: ListenableBuilder(
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
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCanvassBanner(context),
                  const SizedBox(height: 20),
                  const Text(
                    'Saved 3D Building Maps',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
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
    );
  }

  Widget _buildCanvassBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cobaltBlue, Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.view_in_ar, color: AppColors.cyanAccent, size: 28),
              SizedBox(width: 10),
              Text(
                'Register New Building',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Walk around with your phone using ARCore plane tracking and hardware sensors to map corridors, rooms, and multi-story layouts.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: widget.onStartSurvey,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Start Canvassing'),
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
            'Tap "Start Canvassing" above to survey your first building.',
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.apartment, color: AppColors.cyanAccent),
        ),
        title: Text(
          building.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${building.floors.length} Floors • ${building.navGraph.nodes.length} Waypoints',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.cyanAccent, size: 16),
        onTap: () {
          widget.viewModel.selectBuilding(building);
          widget.onSelectBuilding(building);
        },
      ),
    );
  }
}
