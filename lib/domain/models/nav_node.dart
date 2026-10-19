import 'coordinates_3d.dart';

/// The architectural classification of a navigation waypoint.
enum NodeType {
  /// A corridor or hallway passage node.
  hallway,

  /// A target room, office, or destination unit.
  room,

  /// A staircase entry, landing, or exit node.
  stairs,

  /// An elevator cabin or landing door.
  elevator,

  /// An external doorway or building entrance.
  doorway,

  /// A rest area, lobby, or public amenity.
  amenity,
}

/// A spatial waypoint within a building's 3D navigation graph.
class NavNode {
  /// Creates a navigation waypoint.
  const NavNode({
    required this.id,
    required this.name,
    required this.position,
    required this.floorIndex,
    required this.type,
  });

  /// The unique identifier of the node.
  final String id;

  /// The human-readable label or room designation.
  final String name;

  /// The exact 3D spatial coordinate of the node.
  final Coordinates3D position;

  /// The index of the floor on which this node is situated.
  final int floorIndex;

  /// The functional type of the node.
  final NodeType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NavNode($id: "$name", floor: $floorIndex, pos: $position)';
}
