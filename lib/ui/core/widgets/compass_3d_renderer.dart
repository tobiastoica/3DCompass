import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Renders a pitch-and-bearing-compensated 3D vector compass pointer.
class Compass3DRenderer extends StatelessWidget {
  /// Creates a 3D compass widget.
  const Compass3DRenderer({
    super.key,
    required this.targetAzimuthDegrees,
    required this.targetPitchDegrees,
    required this.distanceMeters,
    this.targetLabel,
  });

  /// The horizontal angle in degrees toward the destination.
  final double targetAzimuthDegrees;

  /// The vertical inclination angle in degrees toward the destination.
  final double targetPitchDegrees;

  /// The line-of-sight distance in meters to the destination.
  final double distanceMeters;

  /// The optional descriptive label for the target destination.
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    final hasTarget = targetLabel != null && targetLabel!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(diameter, diameter),
                painter: _Arrow3DPainter(
                  azimuthRad: targetAzimuthDegrees * math.pi / 180.0,
                  pitchRad: targetPitchDegrees * math.pi / 180.0,
                  isActive: hasTarget,
                ),
              ),
              Positioned(
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTarget) ...[
                      Text(
                        '${distanceMeters.toStringAsFixed(1)} m',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyanAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (targetPitchDegrees.abs() > 15.0)
                        Text(
                          targetPitchDegrees > 0 ? '▲ Floor Up' : '▼ Floor Down',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: targetPitchDegrees > 0 ? AppColors.emeraldGreen : AppColors.amberWarning,
                          ),
                        ),
                      Text(
                        targetLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Text(
                        '3D Compass',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const Text(
                        'Ready',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.cyanAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Arrow3DPainter extends CustomPainter {
  _Arrow3DPainter({
    required this.azimuthRad,
    required this.pitchRad,
    required this.isActive,
  });

  final double azimuthRad;
  final double pitchRad;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final radius = math.min(size.width, size.height) * 0.35;

    // Outer compass ring
    final ringPaint = Paint()
      ..color = isActive ? AppColors.cyanAccent.withOpacity(0.3) : Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius + 10, ringPaint);

    // Cardinal tick marks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final p1 = center + Offset(math.cos(angle) * (radius + 6), math.sin(angle) * (radius + 6));
      final p2 = center + Offset(math.cos(angle) * (radius + 14), math.sin(angle) * (radius + 14));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Dynamic 3D transform matrix
    final rot = v64.Matrix4.identity()
      ..rotateZ(azimuthRad)
      ..rotateX(-pitchRad);

    // 3D Arrow vertices in model coordinates: Tip, Left, Right, Base
    final vTip = rot.transformed3(v64.Vector3(0, -radius, 0));
    final vLeft = rot.transformed3(v64.Vector3(-radius * 0.38, radius * 0.42, radius * 0.22));
    final vRight = rot.transformed3(v64.Vector3(radius * 0.38, radius * 0.42, radius * 0.22));
    final vBase = rot.transformed3(v64.Vector3(0, radius * 0.22, -radius * 0.28));

    final tip = center + Offset(vTip.x, vTip.y);
    final left = center + Offset(vLeft.x, vLeft.y);
    final right = center + Offset(vRight.x, vRight.y);
    final base = center + Offset(vBase.x, vBase.y);

    // Shaded facets
    final leftFacePaint = Paint()
      ..color = isActive ? AppColors.cyanAccent : Colors.white60
      ..style = PaintingStyle.fill;

    final rightFacePaint = Paint()
      ..color = isActive ? AppColors.cobaltBlue : Colors.white30
      ..style = PaintingStyle.fill;

    // Draw Left Facet
    final leftPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(base.dx, base.dy)
      ..close();
    canvas.drawPath(leftPath, leftFacePaint);

    // Draw Right Facet
    final rightPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(base.dx, base.dy)
      ..close();
    canvas.drawPath(rightPath, rightFacePaint);

    // Outlines
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftPath, strokePaint);
    canvas.drawPath(rightPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Arrow3DPainter oldDelegate) {
    return oldDelegate.azimuthRad != azimuthRad ||
        oldDelegate.pitchRad != pitchRad ||
        oldDelegate.isActive != isActive;
  }
}
