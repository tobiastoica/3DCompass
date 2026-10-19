import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Presentation card displaying the immediate turn-by-turn instruction.
class TurnByTurnCard extends StatelessWidget {
  /// Creates a turn-by-turn card.
  const TurnByTurnCard({
    super.key,
    required this.instruction,
    this.targetRoom,
    this.onSelectDestination,
  });

  /// The active movement directive.
  final String instruction;

  /// The destination room name, if selected.
  final String? targetRoom;

  /// Callback to change or select a destination.
  final VoidCallback? onSelectDestination;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.cyanAccent,
            radius: 20,
            child: Icon(Icons.navigation, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  targetRoom != null ? 'Target: $targetRoom' : 'No Target Selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instruction,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          if (onSelectDestination != null)
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.cyanAccent),
              onPressed: onSelectDestination,
            ),
        ],
      ),
    );
  }
}
