import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Control panel containing actions to mark rooms, switch/add floors, and finish surveying.
class CanvassActionSheet extends StatelessWidget {
  /// Creates a canvass action sheet.
  const CanvassActionSheet({
    super.key,
    required this.floors,
    required this.activeFloor,
    required this.waypointCount,
    required this.onSelectFloor,
    required this.onAddFloor,
    required this.onMarkRoom,
    required this.onMarkVerticalTransition,
    required this.onFinish,
  });

  /// All building floors registered so far.
  final List<FloorLevel> floors;

  /// The active floor index being surveyed.
  final int activeFloor;

  /// Total waypoints logged so far.
  final int waypointCount;

  /// Callback when user selects an active floor.
  final ValueChanged<int> onSelectFloor;

  /// Callback when user adds a new floor level.
  final ValueChanged<String> onAddFloor;

  /// Callback when user marks a named room or amenity.
  final void Function(String name, NodeType type) onMarkRoom;

  /// Callback when user marks a staircase or elevator.
  final void Function(VerticalTransition type, int targetFloor) onMarkVerticalTransition;

  /// Callback to finalize and bake the building map.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: AppColors.cyanAccent, width: 1.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row: Active Floor, Waypoints & Finish Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cobaltBlue.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                ),
                child: Text(
                  'Active: Floor $activeFloor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$waypointCount Waypoints',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text(
                  'Finish Map',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Floor Switcher Row (Allows surveying any floor directly)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.layers, color: AppColors.cyanAccent, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Survey Floor:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                ...floors.map((f) {
                  final isSelected = f.floorIndex == activeFloor;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: InkWell(
                      onTap: () => onSelectFloor(f.floorIndex),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.cyanAccent : Colors.white12,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.cyanAccent : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          f.name,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Add Floor Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    side: const BorderSide(color: AppColors.cyanAccent, width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _promptAddNewFloor(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('+ Floor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Primary Actions: Add Room & Stairs/Lift
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.cyanAccent, width: 1.2),
                    ),
                  ),
                  onPressed: () => _promptAddRoom(context),
                  icon: const Icon(Icons.meeting_room, color: AppColors.cyanAccent, size: 20),
                  label: const Text(
                    'Add Room',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF374151),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.2),
                    ),
                  ),
                  onPressed: () => _promptAddStairs(context),
                  icon: const Icon(Icons.stairs, color: AppColors.amberWarning, size: 20),
                  label: const Text(
                    'Stairs / Lift',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptAddNewFloor(BuildContext context) {
    final nextIndex = floors.isEmpty ? 0 : floors.map((f) => f.floorIndex).reduce((a, b) => a > b ? a : b) + 1;
    final controller = TextEditingController(text: 'Floor $nextIndex');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.cyanAccent),
              SizedBox(width: 10),
              Text('Add Building Floor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter name for the new floor level:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Floor Name (e.g. Floor 2, Floor 3, Basement)',
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  onAddFloor(name);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add & Switch to Floor', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _promptAddRoom(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.meeting_room, color: AppColors.cyanAccent),
              const SizedBox(width: 10),
              Text(
                'Mark Room (Floor $activeFloor)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter name or room number on Floor $activeFloor:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Room Name (e.g. Room 101, Lab, Restroom)',
                  labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black38,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  onMarkRoom(name, NodeType.room);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save Waypoint', style: TextStyle(fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.stairs, color: AppColors.amberWarning),
              const SizedBox(width: 10),
              Text(
                'Stairs / Lift (From Floor $activeFloor)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Select which floor this staircase or elevator leads to:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const Divider(color: Colors.white12, height: 20),

            // Stairs Up
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white10,
                child: Icon(Icons.arrow_upward, color: AppColors.cyanAccent),
              ),
              title: Text('Stairs Up -> Floor ${activeFloor + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Walk up to next level', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                onMarkVerticalTransition(VerticalTransition.stairs, activeFloor + 1);
                Navigator.of(ctx).pop();
              },
            ),

            // Stairs Down
            if (activeFloor > 0)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.arrow_downward, color: AppColors.amberWarning),
                ),
                title: Text('Stairs Down -> Floor ${activeFloor - 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Walk down to previous level', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  onMarkVerticalTransition(VerticalTransition.stairs, activeFloor - 1);
                  Navigator.of(ctx).pop();
                },
              ),

            // Elevator Up
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white10,
                child: Icon(Icons.elevator, color: Colors.purpleAccent),
              ),
              title: Text('Elevator -> Floor ${activeFloor + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Accessible lift to floor above', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                onMarkVerticalTransition(VerticalTransition.elevator, activeFloor + 1);
                Navigator.of(ctx).pop();
              },
            ),

            // Elevator Down
            if (activeFloor > 0)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.elevator, color: Colors.purpleAccent),
                ),
                title: Text('Elevator -> Floor ${activeFloor - 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Accessible lift to floor below', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  onMarkVerticalTransition(VerticalTransition.elevator, activeFloor - 1);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        );
      },
    );
  }
}
