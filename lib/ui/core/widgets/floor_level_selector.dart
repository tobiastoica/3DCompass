import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// An interactive horizontal pill selector for multi-story buildings.
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers, color: AppColors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: floors.map((floor) {
                  final isSelected = floor.floorIndex == activeFloorIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => onFloorSelected(floor.floorIndex),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.cyanAccent : Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.cyanAccent : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          floor.name,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
