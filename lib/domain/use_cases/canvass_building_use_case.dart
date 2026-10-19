import '../models/building_3d_model.dart';
import '../models/floor_level.dart';
import '../models/nav_edge.dart';
import '../models/nav_graph_3d.dart';
import '../models/nav_node.dart';
import '../repositories/building_repository.dart';

/// Compiles captured ARCore planes, floor levels, and waypoints into a saved 3D building model.
class CanvassBuildingUseCase {
  /// Creates a building canvassing compiler interactor.
  const CanvassBuildingUseCase({
    required BuildingRepository buildingRepository,
  }) : _buildingRepository = buildingRepository;

  final BuildingRepository _buildingRepository;

  /// Compiles the surveyed [nodes], [edges], and [floors] and persists them under [buildingName].
  Future<Building3DModel> execute({
    required String buildingId,
    required String buildingName,
    required List<FloorLevel> floors,
    required Map<String, NavNode> nodes,
    required List<NavEdge> edges,
  }) async {
    final entranceAnchors = nodes.values
        .where((n) => n.type == NodeType.doorway)
        .toList();

    final navGraph = NavGraph3D(nodes: nodes, edges: edges);

    final model = Building3DModel(
      id: buildingId,
      name: buildingName,
      floors: floors,
      navGraph: navGraph,
      entranceAnchors: entranceAnchors,
      createdAt: DateTime.now(),
    );

    await _buildingRepository.saveBuilding(model);
    return model;
  }
}
