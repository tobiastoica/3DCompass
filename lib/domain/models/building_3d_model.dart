import 'coordinates_3d.dart';
import 'floor_level.dart';
import 'nav_graph_3d.dart';
import 'nav_node.dart';

/// Represents a canvassed multi-story building and its navigation layout.
class Building3DModel {
  /// Creates a 3D building model.
  const Building3DModel({
    required this.id,
    required this.name,
    required this.floors,
    required this.navGraph,
    required this.entranceAnchors,
    this.createdAt,
  });

  /// The unique identifier of the building.
  final String id;

  /// The human-readable name of the building.
  final String name;

  /// The collection of distinct vertical floor levels.
  final List<FloorLevel> floors;

  /// The 3D topological navigation graph of the building.
  final NavGraph3D navGraph;

  /// The mapped doorway entrances available for check-in.
  final List<NavNode> entranceAnchors;

  /// The timestamp when this building was surveyed and saved.
  final DateTime? createdAt;

  /// Finds the floor level containing the specified [elevationMeters].
  FloorLevel? findFloorForElevation(double elevationMeters) {
    for (final floor in floors) {
      if (floor.containsElevation(elevationMeters)) {
        return floor;
      }
    }
    return floors.isNotEmpty ? floors.first : null;
  }

  /// Finds the floor level matching [floorIndex].
  FloorLevel? findFloorByIndex(int floorIndex) {
    for (final floor in floors) {
      if (floor.floorIndex == floorIndex) {
        return floor;
      }
    }
    return null;
  }
}
