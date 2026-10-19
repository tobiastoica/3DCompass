import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Control panel containing actions to mark rooms, stairwells, and finish surveying.
class CanvassActionSheet extends StatelessWidget {
  /// Creates a canvass action sheet.
  const CanvassActionSheet({
    super.key,
    required this.onMarkRoom,
    required this.onMarkVerticalTransition,
    required this.onFinish,
    required this.waypointCount,
    required this.activeFloor,
  });

  /// Callback when user marks a named room or amenity.
  final void Function(String name, NodeType type) onMarkRoom;

  /// Callback when user marks a staircase or elevator.
  final void Function(VerticalTransition type, int targetFloor) onMarkVerticalTransition;

  /// Callback to finalize and bake the building map.
  final VoidCallback onFinish;

  /// Total waypoints logged so far.
  final int waypointCount;

  /// The active floor index.
  final int activeFloor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Floor $activeFloor • $waypointCount Waypoints',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Finish Map'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _promptAddRoom(context),
                  icon: const Icon(Icons.meeting_room, color: AppColors.cyanAccent),
                  label: const Text('Add Room'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _promptAddStairs(context),
                  icon: const Icon(Icons.stairs, color: AppColors.cyanAccent),
                  label: const Text('Stairs / Lift'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptAddRoom(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Mark Room / POI', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Room Name or Number',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  onMarkRoom(name, NodeType.room);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Mark'),
            ),
          ],
        );
      },
    );
  }

  void _promptAddStairs(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Vertical Transition', style: TextStyle(color: Colors.white)),
          children: [
            SimpleDialogOption(
              onPressed: () {
                onMarkVerticalTransition(VerticalTransition.stairs, activeFloor + 1);
                Navigator.of(ctx).pop();
              },
              child: Text('Stairs Up -> Floor ${activeFloor + 1}',
                  style: const TextStyle(color: Colors.white)),
            ),
            SimpleDialogOption(
              onPressed: () {
                onMarkVerticalTransition(VerticalTransition.stairs, activeFloor - 1);
                Navigator.of(ctx).pop();
              },
              child: Text('Stairs Down -> Floor ${activeFloor - 1}',
                  style: const TextStyle(color: Colors.white)),
            ),
            SimpleDialogOption(
              onPressed: () {
                onMarkVerticalTransition(VerticalTransition.elevator, activeFloor + 1);
                Navigator.of(ctx).pop();
              },
              child: Text('Elevator -> Floor ${activeFloor + 1}',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
