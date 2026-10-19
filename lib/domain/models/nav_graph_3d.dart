import 'nav_edge.dart';
import 'nav_node.dart';

/// A complete three-dimensional topological navigation network for a building.
class NavGraph3D {
  /// Creates a 3D navigation graph from [nodes] and [edges].
  NavGraph3D({
    required Map<String, NavNode> nodes,
    required List<NavEdge> edges,
  })  : _nodes = Map.unmodifiable(nodes),
        _allEdges = List.unmodifiable(edges) {
    for (final edge in edges) {
      _adjacencyList.putIfAbsent(edge.sourceNodeId, () => []).add(edge);
    }
  }

  final Map<String, NavNode> _nodes;
  final List<NavEdge> _allEdges;
  final Map<String, List<NavEdge>> _adjacencyList = {};

  /// The dictionary of navigation waypoints keyed by node identifier.
  Map<String, NavNode> get nodes => _nodes;

  /// The complete list of traversable segments across all floors.
  List<NavEdge> get allEdges => _allEdges;

  /// Retrieves the outgoing edges originating from [nodeId].
  List<NavEdge> getOutgoingEdges(String nodeId) {
    return _adjacencyList[nodeId] ?? const [];
  }

  /// Retrieves all navigation nodes belonging to the specified [floorIndex].
  List<NavNode> getNodesForFloor(int floorIndex) {
    return _nodes.values.where((n) => n.floorIndex == floorIndex).toList();
  }

  /// Returns the closest node to [targetPosition] on the specified [floorIndex].
  NavNode? findClosestNode(dynamic targetPosition, int floorIndex) {
    final floorNodes = getNodesForFloor(floorIndex);
    if (floorNodes.isEmpty) return null;

    NavNode? closest;
    var minDistance = double.infinity;

    for (final node in floorNodes) {
      final dist = node.position.distanceTo(targetPosition);
      if (dist < minDistance) {
        minDistance = dist;
        closest = node;
      }
    }

    return closest;
  }
}
