import 'dart:math' as math;
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
    return SizedBox.expand(
      child: Container(
        color: const Color(0xFF0B1120),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // AR Feature Grid & Horizon reference
            Positioned.fill(
              child: CustomPaint(
                painter: _ArPerspectiveGridPainter(),
              ),
            ),

            // Central AR Viewfinder Reticle
            CustomPaint(
              size: const Size(220, 220),
              painter: _ReticlePainter(),
            ),

            // Top Status Badge: AR Tracking & Planes
            Positioned(
              top: 20,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTracking ? Icons.sensors : Icons.sensors_off,
                        color: isTracking ? AppColors.emeraldGreen : AppColors.amberWarning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isTracking
                            ? 'ARCore Tracking Active • $detectedPlaneCount Planes'
                            : 'Initializing Sensor Fusion...',
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
            ),

            // Center Guidance Message
            Positioned(
              bottom: 230,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, color: AppColors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Walk forward through corridors. Tap "Add Room" or "Stairs" as you reach them.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArPerspectiveGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.06)
      ..strokeWidth = 1.0;

    final horizonY = size.height * 0.52;
    final centerX = size.width / 2;

    // Horizon line
    final horizonPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.18)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), horizonPaint);

    // Perspective floor lines radiating from center horizon
    for (var i = -4; i <= 4; i++) {
      final start = Offset(centerX + i * 28.0, horizonY);
      final end = Offset(centerX + i * (size.width / 3.5), size.height);
      canvas.drawLine(start, end, gridPaint);
    }

    // Horizontal floor grid lines
    for (var y = horizonY + 25; y < size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 26.0;
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

    // Center crosshair
    final center = Offset(size.width / 2, size.height / 2);
    final dotPaint = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, dotPaint);

    const crossLength = 10.0;
    canvas.drawLine(center - const Offset(crossLength, 0), center + const Offset(crossLength, 0), paint);
    canvas.drawLine(center - const Offset(0, crossLength), center + const Offset(0, crossLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
