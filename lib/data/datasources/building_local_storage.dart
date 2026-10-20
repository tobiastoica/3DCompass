import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/building_3d_model.dart';
import '../../domain/models/floor_level.dart';
import '../../domain/models/nav_graph_3d.dart';
import '../../domain/models/nav_node.dart';
import 'binary_nav_serializer.dart';

/// Manages filesystem persistence of `.3dnav` binary models and metadata in local storage.
class BuildingLocalStorage {
  /// Creates a local storage manager.
  BuildingLocalStorage({
    BinaryNavSerializer? serializer,
  }) : _serializer = serializer ?? BinaryNavSerializer();

  final BinaryNavSerializer _serializer;

  /// Retrieves the directory designated for `.3dnav` building map files.
  Future<Directory> get _mapsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final mapsDir = Directory('${appDir.path}/maps_3d');
    if (!await mapsDir.exists()) {
      await mapsDir.create(recursive: true);
    }
    return mapsDir;
  }

  /// Writes [building] as a binary `.3dnav` file and JSON metadata to local storage.
  Future<void> saveBuilding(Building3DModel building) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/${building.id}.3dnav');

    final bytes = _serializer.serialize(
      graph: building.navGraph,
      floors: building.floors,
    );

    await file.writeAsBytes(bytes, flush: true);

    // Save metadata companion file to preserve all human-readable room and floor names
    final metaFile = File('${dir.path}/${building.id}.meta.json');
    final meta = {
      'id': building.id,
      'name': building.name,
      'floors': building.floors.map((f) => {
        'floorIndex': f.floorIndex,
        'name': f.name,
        'baseElevationMeters': f.baseElevationMeters,
        'floorHeightMeters': f.floorHeightMeters,
      }).toList(),
      'nodeNames': {
        for (final entry in building.navGraph.nodes.entries)
          entry.key: entry.value.name,
      },
    };
    await metaFile.writeAsString(jsonEncode(meta), flush: true);
  }

  /// Loads and deserializes a building by its [id].
  Future<Building3DModel?> loadBuilding(String id, String name) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/$id.3dnav');
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final decoded = _serializer.deserialize(bytes);

    var floors = decoded.floors;
    var buildingName = name;
    final nodeNameMap = <String, String>{};

    final metaFile = File('${dir.path}/$id.meta.json');
    if (await metaFile.exists()) {
      try {
        final metaContent = await metaFile.readAsString();
        final metaJson = jsonDecode(metaContent) as Map<String, dynamic>;
        if (metaJson['name'] is String) buildingName = metaJson['name'] as String;
        if (metaJson['floors'] is List) {
          floors = (metaJson['floors'] as List).map((f) {
            final fm = f as Map<String, dynamic>;
            return FloorLevel(
              floorIndex: fm['floorIndex'] as int,
              name: fm['name'] as String,
              baseElevationMeters: (fm['baseElevationMeters'] as num).toDouble(),
              floorHeightMeters: (fm['floorHeightMeters'] as num).toDouble(),
            );
          }).toList();
        }
        if (metaJson['nodeNames'] is Map) {
          final nMap = metaJson['nodeNames'] as Map;
          for (final k in nMap.keys) {
            nodeNameMap[k.toString()] = nMap[k].toString();
          }
        }
      } catch (_) {
        // Fallback to binary values if metadata read fails
      }
    }

    // Restore human-readable node names
    final restoredNodes = <String, NavNode>{};
    for (final node in decoded.graph.nodes.values) {
      final restoredName = nodeNameMap[node.id] ?? node.name;
      restoredNodes[node.id] = NavNode(
        id: node.id,
        name: restoredName,
        position: node.position,
        floorIndex: node.floorIndex,
        type: node.type,
      );
    }

    return Building3DModel(
      id: id,
      name: buildingName,
      floors: floors,
      navGraph: NavGraph3D(nodes: restoredNodes, edges: decoded.graph.allEdges),
      entranceAnchors: restoredNodes.values
          .where((n) => n.type.name == 'doorway')
          .toList(),
    );
  }

  /// Deletes the building files associated with [id].
  Future<void> deleteBuilding(String id) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/$id.3dnav');
    if (await file.exists()) {
      await file.delete();
    }
    final metaFile = File('${dir.path}/$id.meta.json');
    if (await metaFile.exists()) {
      await metaFile.delete();
    }
  }

  /// Lists all building IDs currently saved on disk.
  Future<List<String>> listBuildingIds() async {
    final dir = await _mapsDirectory;
    final entities = await dir.list().toList();
    final ids = <String>[];
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.3dnav')) {
        final filename = entity.uri.pathSegments.last;
        ids.add(filename.replaceAll('.3dnav', ''));
      }
    }
    return ids;
  }
}
