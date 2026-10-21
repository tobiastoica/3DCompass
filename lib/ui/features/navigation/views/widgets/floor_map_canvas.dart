import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/building_3d_model.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/navigation_path.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Renders an interactive vector canvas representing the active building floor plan with pan, zoom, and readable labels.
class FloorMapCanvas extends StatefulWidget {
  /// Creates an interactive floor map canvas.
  const FloorMapCanvas({
    super.key,
    required this.building,
    required this.activeFloorIndex,
    required this.userPosition,
    this.activePath,
  });

  /// The building model containing the floor geometry.
  final Building3DModel? building;

  /// The currently rendered floor level.
  final int activeFloorIndex;

  /// The estimated user position.
  final Coordinates3D userPosition;

  /// The active navigation route path, if any.
  final NavigationPath? activePath;

  @override
  State<FloorMapCanvas> createState() => _FloorMapCanvasState();
}

class _FloorMapCanvasState extends State<FloorMapCanvas> {
  Offset _panOffset = Offset.zero;
  double _zoomScale = 1.0;
  double _baseScale = 1.0;

  void _recenter() {
    setState(() {
      _panOffset = Offset.zero;
      _zoomScale = 1.0;
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomScale = (_zoomScale * 1.3).clamp(0.35, 6.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomScale = (_zoomScale / 1.3).clamp(0.35, 6.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pan & Pinch-Zoom Vector Map Canvas
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _baseScale = _zoomScale;
          },
          onScaleUpdate: (details) {
            setState(() {
              _zoomScale = (_baseScale * details.scale).clamp(0.35, 6.0);
              _panOffset += details.focalPointDelta;
            });
          },
          child: SizedBox.expand(
            child: Container(
              color: const Color(0xFF0A0F1D),
              child: CustomPaint(
                painter: _FloorPlanPainter(
                  building: widget.building,
                  floorIndex: widget.activeFloorIndex,
                  userPos: widget.userPosition,
                  path: widget.activePath,
                  panOffset: _panOffset,
                  zoomScale: _zoomScale,
                ),
              ),
            ),
          ),
        ),

        // Zoom & Recenter Control Buttons Floating Bar
        Positioned(
          right: 16,
          bottom: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom In (+) Button
              _buildFloatingBtn(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onTap: _zoomIn,
              ),
              const SizedBox(height: 8),

              // Zoom Out (-) Button
              _buildFloatingBtn(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onTap: _zoomOut,
              ),
              const SizedBox(height: 8),

              // Recenter Button
              _buildFloatingBtn(
                icon: Icons.my_location,
                tooltip: 'Recenter on User',
                onTap: _recenter,
                iconColor: AppColors.cyanAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: AppColors.surfaceDark.withOpacity(0.92),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.cyanAccent.withOpacity(0.4),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorPlanPainter extends CustomPainter {
  _FloorPlanPainter({
    required this.building,
    required this.floorIndex,
    required this.userPos,
    required this.path,
    required this.panOffset,
    required this.zoomScale,
  });

  final Building3DModel? building;
  final int floorIndex;
  final Coordinates3D userPos;
  final NavigationPath? path;
  final Offset panOffset;
  final double zoomScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;
    final scale = 14.0 * zoomScale; // Scaled pixels per meter

    // Grid lines for scale reference
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0;
    final gridSpacing = 5.0 * scale; // 5 meters grid
    if (gridSpacing > 10.0) {
      final startX = (center.dx % gridSpacing) - gridSpacing;
      for (var x = startX; x < size.width + gridSpacing; x += gridSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      final startY = (center.dy % gridSpacing) - gridSpacing;
      for (var y = startY; y < size.height + gridSpacing; y += gridSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    if (building == null) return;

    // Draw Floor Corridors / Edges
    final edgePaint = Paint()
      ..color = const Color(0xFF334155) // Slate 700 corridor paths
      ..strokeWidth = 8.0 * zoomScale.clamp(0.6, 1.8)
      ..strokeCap = StrokeCap.round;

    final edgeGlowPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2.0 * zoomScale.clamp(0.6, 1.8)
      ..strokeCap = StrokeCap.round;

    for (final edge in building!.navGraph.allEdges) {
      final s = building!.navGraph.nodes[edge.sourceNodeId];
      final t = building!.navGraph.nodes[edge.targetNodeId];
      if (s != null && t != null && s.floorIndex == floorIndex && t.floorIndex == floorIndex) {
        final p1 = center + Offset(s.position.x * scale, -s.position.y * scale);
        final p2 = center + Offset(t.position.x * scale, -t.position.y * scale);
        canvas.drawLine(p1, p2, edgePaint);
        canvas.drawLine(p1, p2, edgeGlowPaint);
      }
    }

    // Draw Active Navigation Path
    if (path != null && path!.isNotEmpty) {
      final pathPoints = path!.waypoints.where((w) => w.floorIndex == floorIndex).toList();
      if (pathPoints.length >= 2) {
        final pathGlowPaint = Paint()
          ..color = AppColors.cyanAccent.withOpacity(0.35)
          ..strokeWidth = 10.0 * zoomScale.clamp(0.6, 1.8)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final pathPaint = Paint()
          ..color = AppColors.cyanAccent
          ..strokeWidth = 4.0 * zoomScale.clamp(0.6, 1.8)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final route = Path();
        final first = center + Offset(pathPoints.first.position.x * scale, -pathPoints.first.position.y * scale);
        route.moveTo(first.dx, first.dy);
        for (var i = 1; i < pathPoints.length; i++) {
          final pt = center + Offset(pathPoints[i].position.x * scale, -pathPoints[i].position.y * scale);
          route.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(route, pathGlowPaint);
        canvas.drawPath(route, pathPaint);
      }
    }

    // Draw Floor Nodes with Readable Labels
    for (final node in building!.navGraph.getNodesForFloor(floorIndex)) {
      final pos = center + Offset(node.position.x * scale, -node.position.y * scale);

      Color nodeColor;
      if (node.type.name == 'room') {
        nodeColor = AppColors.cobaltBlue;
      } else if (node.type.name == 'stairs') {
        nodeColor = AppColors.amberWarning;
      } else if (node.type.name == 'doorway') {
        nodeColor = AppColors.emeraldGreen;
      } else {
        nodeColor = Colors.white54;
      }

      // Draw node circle
      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 7.0 * zoomScale.clamp(0.6, 1.5), nodePaint);

      final nodeRingPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, 7.0 * zoomScale.clamp(0.6, 1.5), nodeRingPaint);

      // Render Node Label with Dark Pill Background for maximum legibility
      if (node.name.isNotEmpty && node.type.name != 'hallway') {
        final textSpan = TextSpan(
          text: node.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: (11 * zoomScale.clamp(0.8, 1.3)).clamp(9.0, 15.0),
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final labelOffset = pos + Offset(-textPainter.width / 2, 11 * zoomScale.clamp(0.8, 1.4));
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            labelOffset.dx - 6,
            labelOffset.dy - 3,
            textPainter.width + 12,
            textPainter.height + 6,
          ),
          const Radius.circular(6),
        );

        final bgPaint = Paint()..color = const Color(0xDD0F172A);
        final bgBorderPaint = Paint()
          ..color = nodeColor.withOpacity(0.7)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        canvas.drawRRect(bgRect, bgPaint);
        canvas.drawRRect(bgRect, bgBorderPaint);
        textPainter.paint(canvas, labelOffset);
      }
    }

    // Draw User Location Pin & Direction Heading
    final userScreenPos = center + Offset(userPos.x * scale, -userPos.y * scale);

    // Pulsing Halo
    final userHaloPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userScreenPos, 18.0 * zoomScale.clamp(0.7, 1.5), userHaloPaint);

    final userPinPaint = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userScreenPos, 7.5 * zoomScale.clamp(0.7, 1.5), userPinPaint);

    final userPinBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(userScreenPos, 7.5 * zoomScale.clamp(0.7, 1.5), userPinBorderPaint);

    // "YOU" Label over user position
    final youSpan = const TextSpan(
      text: 'YOU',
      style: TextStyle(
        color: AppColors.cyanAccent,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
    final youPainter = TextPainter(
      text: youSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    youPainter.paint(
      canvas,
      userScreenPos + Offset(-youPainter.width / 2, -22 * zoomScale.clamp(0.7, 1.5)),
    );
  }

  @override
  bool shouldRepaint(covariant _FloorPlanPainter oldDelegate) {
    return oldDelegate.floorIndex != floorIndex ||
        oldDelegate.userPos != userPos ||
        oldDelegate.path != path ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.zoomScale != zoomScale;
  }
}
