import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/compass_3d_renderer.dart';

/// Floating HUD container holding the 3D Vector Compass.
class NavigationHudOverlay extends StatelessWidget {
  /// Creates a navigation HUD overlay.
  const NavigationHudOverlay({
    super.key,
    required this.targetAzimuthDegrees,
    required this.targetPitchDegrees,
    required this.distanceMeters,
    this.targetLabel,
  });

  /// The horizontal azimuth angle toward the destination in degrees.
  final double targetAzimuthDegrees;

  /// The vertical inclination pitch angle toward the destination in degrees.
  final double targetPitchDegrees;

  /// Distance in meters to target.
  final double distanceMeters;

  /// Target room or destination name.
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Compass3DRenderer(
        targetAzimuthDegrees: targetAzimuthDegrees,
        targetPitchDegrees: targetPitchDegrees,
        distanceMeters: distanceMeters,
        targetLabel: targetLabel,
      ),
    );
  }
}
