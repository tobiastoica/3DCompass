import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// An interactive vertical or horizontal pill selector for multi-story buildings.
class FloorLevelSelector extends StatelessWidget {
  /// Creates a floor level selector.
  const FloorLevelSelector({
    super.key,
    required this.floors,
    required this.activeFloorIndex,
    required this.onFloorSelected,
  });

  /// The list of building floors.
  final List<FloorLevel> floors;

  /// The floor index currently being viewed or tracked.
  final int activeFloorIndex;

  /// Callback invoked when a floor is tapped.
  final ValueChanged<int> onFloorSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: floors.map((floor) {
          final isSelected = floor.floorIndex == activeFloorIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                floor.name,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.cyanAccent,
              backgroundColor: Colors.transparent,
              onSelected: (_) => onFloorSelected(floor.floorIndex),
            ),
          );
        }).toList(),
      ),
    );
  }
}
