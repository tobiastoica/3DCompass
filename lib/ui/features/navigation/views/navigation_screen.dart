import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/ui/core/constants/app_breakpoints.dart';
import 'package:compass_3d/ui/core/widgets/floor_level_selector.dart';
import 'package:compass_3d/ui/core/widgets/sensor_status_badge.dart';
import 'package:compass_3d/ui/features/doorway_checkin/views/doorway_checkin_dialog.dart';
import '../view_models/navigation_view_model.dart';
import 'widgets/floor_map_canvas.dart';
import 'widgets/navigation_hud_overlay.dart';
import 'widgets/turn_by_turn_card.dart';

/// Primary navigation screen featuring adaptive 3D compass guidance.
class NavigationScreen extends StatefulWidget {
  /// Creates a navigation screen.
  const NavigationScreen({
    super.key,
    required this.viewModel,
    this.doorwayCheckinDialogBuilder,
  });

  /// The view model driving the navigation state.
  final NavigationViewModel viewModel;

  /// Optional builder to show the doorway check-in dialog.
  final Widget Function(BuildContext context, VoidCallback onComplete)? doorwayCheckinDialogBuilder;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _viewingFloorIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.viewModel.startNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final building = widget.viewModel.activeBuilding;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.viewModel.buildingName),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: SensorStatusBadge(
                  isCalibrated: widget.viewModel.isCalibrated,
                  accuracyMeters: widget.viewModel.accuracyMeters,
                  onTapDoorwayCheckin: () => _openDoorwayCheckin(context),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= AppBreakpoints.largeScreenMinWidth) {
                return _buildExpandedLayout(building);
              } else {
                return _buildCompactLayout(building);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildExpandedLayout(dynamic building) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              FloorMapCanvas(
                building: building,
                activeFloorIndex: _viewingFloorIndex,
                userPosition: widget.viewModel.userPosition,
                activePath: widget.viewModel.activePath,
              ),
              if (building != null && building.floors.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  child: FloorLevelSelector(
                    floors: building.floors,
                    activeFloorIndex: _viewingFloorIndex,
                    onFloorSelected: (f) => setState(() => _viewingFloorIndex = f),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.white12),
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: NavigationHudOverlay(
                        targetAzimuthDegrees: widget.viewModel.bearingToTarget,
                        targetPitchDegrees: widget.viewModel.pitchToTarget,
                        distanceMeters: widget.viewModel.distanceToTarget,
                        targetLabel: widget.viewModel.targetDestination?.name,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TurnByTurnCard(
                      instruction: widget.viewModel.currentInstruction,
                      targetRoom: widget.viewModel.targetDestination?.name,
                      onSelectDestination: () => _openDestinationPicker(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(dynamic building) {
    return Stack(
      children: [
        FloorMapCanvas(
          building: building,
          activeFloorIndex: _viewingFloorIndex,
          userPosition: widget.viewModel.userPosition,
          activePath: widget.viewModel.activePath,
        ),
        if (building != null && building.floors.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            child: FloorLevelSelector(
              floors: building.floors,
              activeFloorIndex: _viewingFloorIndex,
              onFloorSelected: (f) => setState(() => _viewingFloorIndex = f),
            ),
          ),
        Positioned(
          top: 72,
          right: 16,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160, maxHeight: 180),
            child: NavigationHudOverlay(
              targetAzimuthDegrees: widget.viewModel.bearingToTarget,
              targetPitchDegrees: widget.viewModel.pitchToTarget,
              distanceMeters: widget.viewModel.distanceToTarget,
              targetLabel: widget.viewModel.targetDestination?.name,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: TurnByTurnCard(
            instruction: widget.viewModel.currentInstruction,
            targetRoom: widget.viewModel.targetDestination?.name,
            onSelectDestination: () => _openDestinationPicker(context),
          ),
        ),
      ],
    );
  }

  void _openDestinationPicker(BuildContext context) {
    final building = widget.viewModel.activeBuilding;
    if (building == null) return;

    final rooms = building.navGraph.nodes.values
        .where((n) => n.type == NodeType.room || n.type == NodeType.amenity)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Target Destination',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (ctx, index) {
                    final room = rooms[index];
                    return ListTile(
                      leading: const Icon(Icons.room, color: Colors.cyanAccent),
                      title: Text(room.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Floor ${room.floorIndex}', style: const TextStyle(color: Colors.white54)),
                      onTap: () {
                        widget.viewModel.selectDestination(room);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDoorwayCheckin(BuildContext context) {
    if (widget.doorwayCheckinDialogBuilder != null) {
      showDialog<void>(
        context: context,
        builder: (ctx) => widget.doorwayCheckinDialogBuilder!(ctx, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrance datum calibrated!')),
          );
        }),
      );
    }
  }
}
