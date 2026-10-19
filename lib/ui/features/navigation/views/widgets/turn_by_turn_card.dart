import 'package:flutter/material.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

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
    final hasTarget = targetRoom != null && targetRoom!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelectDestination,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: hasTarget ? AppColors.surfaceDark : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasTarget ? AppColors.cyanAccent.withOpacity(0.4) : AppColors.cyanAccent,
              width: hasTarget ? 1.2 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: hasTarget ? Colors.black54 : AppColors.cyanAccent.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTarget ? AppColors.cyanAccent : const Color(0xFF0F766E),
                ),
                child: Icon(
                  hasTarget ? Icons.navigation : Icons.search,
                  color: hasTarget ? Colors.black : AppColors.cyanAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasTarget) ...[
                      const Row(
                        children: [
                          Text(
                            'Select Destination Room',
                            style: TextStyle(
                              color: AppColors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: AppColors.cyanAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Tap here to choose where you want to go',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Target: $targetRoom',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Change',
                              style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instruction,
                        style: const TextStyle(
                          color: AppColors.cyanAccent,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
