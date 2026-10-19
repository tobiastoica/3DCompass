import 'package:flutter/material.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Renders a camera viewfinder HUD overlay for ARCore surveying.
class ArViewfinderWidget extends StatelessWidget {
  /// Creates an AR viewfinder widget.
  const ArViewfinderWidget({
    super.key,
    required this.detectedPlaneCount,
    required this.isTracking,
  });

  /// The count of structural planes recognized by ARCore.
  final int detectedPlaneCount;

  /// Whether the AR tracking session is active.
  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated AR camera reticle
          CustomPaint(
            size: const Size(200, 200),
            painter: _ReticlePainter(),
          ),
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    isTracking ? Icons.videocam : Icons.videocam_off,
                    color: AppColors.cyanAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ARCore Planes: $detectedPlaneCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const cornerLength = 24.0;
    // Top-left
    canvas.drawLine(Offset.zero, const Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
