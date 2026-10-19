import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/ui/core/constants/app_breakpoints.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';
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
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            title: Text(
              widget.viewModel.buildingName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.cyanAccent),
                tooltip: 'How to Navigate',
                onPressed: () => _showHelpDialog(context),
              ),
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
            fit: StackFit.expand,
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
      fit: StackFit.expand,
      children: [
        // Full screen vector floor plan
        FloorMapCanvas(
          building: building,
          activeFloorIndex: _viewingFloorIndex,
          userPosition: widget.viewModel.userPosition,
          activePath: widget.viewModel.activePath,
        ),

        // Top Floor Level Selector
        if (building != null && building.floors.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 170, // Leave space for HUD
            child: FloorLevelSelector(
              floors: building.floors,
              activeFloorIndex: _viewingFloorIndex,
              onFloorSelected: (f) => setState(() => _viewingFloorIndex = f),
            ),
          ),

        // Floating 3D Compass HUD in top-right
        Positioned(
          top: 12,
          right: 12,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150, maxHeight: 160),
            child: NavigationHudOverlay(
              targetAzimuthDegrees: widget.viewModel.bearingToTarget,
              targetPitchDegrees: widget.viewModel.pitchToTarget,
              distanceMeters: widget.viewModel.distanceToTarget,
              targetLabel: widget.viewModel.targetDestination?.name,
            ),
          ),
        ),

        // Bottom Turn-by-Turn Directive Card (Wrapped in SafeArea to prevent nav-bar overlap)
        Positioned(
          bottom: 12,
          left: 14,
          right: 14,
          child: SafeArea(
            top: false,
            child: TurnByTurnCard(
              instruction: widget.viewModel.currentInstruction,
              targetRoom: widget.viewModel.targetDestination?.name,
              onSelectDestination: () => _openDestinationPicker(context),
            ),
          ),
        ),
      ],
    );
  }

  void _openDestinationPicker(BuildContext context) {
    final building = widget.viewModel.activeBuilding;
    if (building == null) return;

    final rooms = building.navGraph.nodes.values
        .where((n) => n.type == NodeType.room || n.type == NodeType.amenity || n.type == NodeType.stairs)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.near_me, color: AppColors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Select Destination Room',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap any room below to start 3D compass navigation:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (ctx, index) {
                      final room = rooms[index];
                      final isStairs = room.type == NodeType.stairs;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isStairs ? AppColors.amberWarning.withOpacity(0.2) : AppColors.cobaltBlue.withOpacity(0.3),
                          child: Icon(
                            isStairs ? Icons.stairs : Icons.meeting_room,
                            color: isStairs ? AppColors.amberWarning : AppColors.cyanAccent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          room.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          'Floor ${room.floorIndex} • Node: ${room.id}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.cyanAccent, size: 14),
                        onTap: () {
                          widget.viewModel.selectDestination(room);
                          setState(() {
                            _viewingFloorIndex = room.floorIndex;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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
            const SnackBar(
              backgroundColor: AppColors.emeraldGreen,
              content: Text(
                '✓ Doorway calibrated! Baseline pressure and origin locked.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      );
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.explore, color: AppColors.cyanAccent),
            SizedBox(width: 10),
            Text('How 3D Compass Works', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpBullet(
              icon: Icons.door_front_door,
              iconColor: AppColors.emeraldGreen,
              title: '1. Doorway Calibration',
              text: 'Tap the badge at top right when entering. This anchors your starting point and sets the barometric zero datum without GPS or internet.',
            ),
            SizedBox(height: 12),
            _HelpBullet(
              icon: Icons.near_me,
              iconColor: AppColors.cyanAccent,
              title: '2. Pick Destination',
              text: 'Tap the bottom card to choose which room or floor you want to reach.',
            ),
            SizedBox(height: 12),
            _HelpBullet(
              icon: Icons.screen_rotation,
              iconColor: AppColors.amberWarning,
              title: '3. Follow the 3D Needle',
              text: 'Hold phone naturally. The 3D needle calculates pitch & bearing, pointing directly through floors toward your target.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HelpBullet extends StatelessWidget {
  const _HelpBullet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
