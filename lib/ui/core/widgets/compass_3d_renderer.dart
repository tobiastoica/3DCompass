import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import '../theme/app_colors.dart';

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
                ),
              ),
              Positioned(
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${distanceMeters.toStringAsFixed(1)} m',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyanAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (targetLabel != null)
                      Text(
                        targetLabel!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
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
  });

  final double azimuthRad;
  final double pitchRad;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 14);
    final radius = math.min(size.width, size.height) * 0.36;

    // Outer compass ring
    final ringPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius + 12, ringPaint);

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
      ..color = AppColors.cyanAccent.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    final rightFacePaint = Paint()
      ..color = AppColors.cobaltBlue.withOpacity(0.95)
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
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leftPath, strokePaint);
    canvas.drawPath(rightPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Arrow3DPainter oldDelegate) {
    return oldDelegate.azimuthRad != azimuthRad || oldDelegate.pitchRad != pitchRad;
  }
}
