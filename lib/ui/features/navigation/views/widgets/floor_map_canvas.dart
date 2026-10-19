import 'package:flutter/material.dart';
import 'package:compass_3d/domain/models/building_3d_model.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/navigation_path.dart';
import 'package:compass_3d/ui/core/theme/app_colors.dart';

/// Renders a dynamic vector canvas representing the active building floor plan.
class FloorMapCanvas extends StatelessWidget {
  /// Creates a floor map canvas.
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
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: CustomPaint(
        size: Size.infinite,
        painter: _FloorPlanPainter(
          building: building,
          floorIndex: activeFloorIndex,
          userPos: userPosition,
          path: activePath,
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
  });

  final Building3DModel? building;
  final int floorIndex;
  final Coordinates3D userPos;
  final NavigationPath? path;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const scale = 14.0; // 14 pixels per meter

    // Grid lines for scale reference
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    const gridSpacing = 5.0 * scale; // 5 meters grid
    for (var x = 0.0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (building == null) return;

    // Draw Floor Edges
    final edgePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (final edge in building!.navGraph.allEdges) {
      final s = building!.navGraph.nodes[edge.sourceNodeId];
      final t = building!.navGraph.nodes[edge.targetNodeId];
      if (s != null && t != null && s.floorIndex == floorIndex && t.floorIndex == floorIndex) {
        final p1 = center + Offset(s.position.x * scale, -s.position.y * scale);
        final p2 = center + Offset(t.position.x * scale, -t.position.y * scale);
        canvas.drawLine(p1, p2, edgePaint);
      }
    }

    // Draw Active Navigation Path
    if (path != null && path!.isNotEmpty) {
      final pathPaint = Paint()
        ..color = AppColors.cyanAccent
        ..strokeWidth = 4.5
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final pathPoints = path!.waypoints.where((w) => w.floorIndex == floorIndex).toList();
      if (pathPoints.length >= 2) {
        final route = Path();
        final first = center + Offset(pathPoints.first.position.x * scale, -pathPoints.first.position.y * scale);
        route.moveTo(first.dx, first.dy);
        for (var i = 1; i < pathPoints.length; i++) {
          final pt = center + Offset(pathPoints[i].position.x * scale, -pathPoints[i].position.y * scale);
          route.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(route, pathPaint);
      }
    }

    // Draw Floor Nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (final node in building!.navGraph.getNodesForFloor(floorIndex)) {
      final pos = center + Offset(node.position.x * scale, -node.position.y * scale);
      nodePaint.color = node.type.name == 'room'
          ? AppColors.cobaltBlue
          : (node.type.name == 'stairs' ? AppColors.amberWarning : Colors.white54);
      canvas.drawCircle(pos, 5.0, nodePaint);
    }

    // Draw User Location Pin
    final userScreenPos = center + Offset(userPos.x * scale, -userPos.y * scale);
    final userHaloPaint = Paint()
      ..color = AppColors.cyanAccent.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userScreenPos, 14.0, userHaloPaint);

    final userPinPaint = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userScreenPos, 6.0, userPinPaint);
  }

  @override
  bool shouldRepaint(covariant _FloorPlanPainter oldDelegate) {
    return oldDelegate.floorIndex != floorIndex ||
        oldDelegate.userPos != userPos ||
        oldDelegate.path != path;
  }
}
