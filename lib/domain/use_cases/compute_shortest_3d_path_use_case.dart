import 'package:collection/collection.dart';
import '../models/coordinates_3d.dart';
import '../models/nav_edge.dart';
import '../models/nav_graph_3d.dart';
import '../models/nav_node.dart';
import '../models/navigation_path.dart';

/// Computes the optimal 3D path across floors using A* search.
class ComputeShortest3DPathUseCase {
  /// Creates a pathfinding interactor.
  const ComputeShortest3DPathUseCase();

  /// Executes 3D A* search on [graph] from [startNodeId] to [targetNodeId].
  ///
  /// Takes vertical transition penalties (stairs vs. elevators) into account.
  /// If [requireElevatorOnly] is `true`, routes strictly via elevators and ramps.
  /// Throws an [ArgumentError] if the start or target node is missing from [graph].
  NavigationPath execute({
    required NavGraph3D graph,
    required String startNodeId,
    required String targetNodeId,
    bool requireElevatorOnly = false,
  }) {
    final startNode = graph.nodes[startNodeId];
    final targetNode = graph.nodes[targetNodeId];

    if (startNode == null) {
      throw ArgumentError('Start node "$startNodeId" not found in graph.');
    }
    if (targetNode == null) {
      throw ArgumentError('Target node "$targetNodeId" not found in graph.');
    }

    if (startNodeId == targetNodeId) {
      return NavigationPath(waypoints: [startNode]);
    }

    final openSet = PriorityQueue<_NodeScore>(
      (a, b) => a.fScore.compareTo(b.fScore),
    );
    final closedSet = <String>{};
    final cameFrom = <String, NavNode>{};
    final gScore = <String, double>{startNodeId: 0.0};

    openSet.add(_NodeScore(
      node: startNode,
      fScore: _heuristic(startNode.position, targetNode.position),
    ));

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst().node;

      if (current.id == targetNodeId) {
        return _reconstructPath(cameFrom, current);
      }

      closedSet.add(current.id);

      for (final edge in graph.getOutgoingEdges(current.id)) {
        if (requireElevatorOnly && edge.transitionType == VerticalTransition.stairs) {
          continue;
        }

        final neighbor = graph.nodes[edge.targetNodeId];
        if (neighbor == null || closedSet.contains(neighbor.id)) {
          continue;
        }

        // Apply ergonomic weight penalty for stairs
        final transitionPenalty = edge.transitionType == VerticalTransition.stairs ? 5.0 : 0.0;
        final tentativeG = gScore[current.id]! + edge.distanceMeters + transitionPenalty;

        if (tentativeG < (gScore[neighbor.id] ?? double.infinity)) {
          cameFrom[neighbor.id] = current;
          gScore[neighbor.id] = tentativeG;
          final fScore = tentativeG + _heuristic(neighbor.position, targetNode.position);
          openSet.add(_NodeScore(node: neighbor, fScore: fScore));
        }
      }
    }

    throw StateError('No traversable path exists between "$startNodeId" and "$targetNodeId".');
  }

  /// Calculates the Euclidean 3D distance heuristic.
  double _heuristic(Coordinates3D from, Coordinates3D to) {
    return from.distanceTo(to);
  }

  /// Reconstructs the waypoint path from the came-from mapping.
  NavigationPath _reconstructPath(Map<String, NavNode> cameFrom, NavNode current) {
    final nodes = <NavNode>[current];
    var curr = current;
    while (cameFrom.containsKey(curr.id)) {
      curr = cameFrom[curr.id]!;
      nodes.insert(0, curr);
    }
    return NavigationPath(waypoints: nodes);
  }
}

class _NodeScore {
  _NodeScore({required this.node, required this.fScore});
  final NavNode node;
  final double fScore;
}
