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

  /// Retrieves the external persistent backup directory in the public Downloads folder.
  Future<Directory?> get _externalBackupDirectory async {
    try {
      final extDir = Directory('/storage/emulated/0/Download/3DCompass_Maps');
      if (!await extDir.exists()) {
        await extDir.create(recursive: true);
      }
      return extDir;
    } catch (_) {
      return null;
    }
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

    // Also persist an external backup in the phone's Downloads directory
    // so data is never lost even if the user uninstalls the application
    try {
      final extDir = await _externalBackupDirectory;
      if (extDir != null) {
        final extFile = File('${extDir.path}/${building.id}.3dnav');
        await extFile.writeAsBytes(bytes, flush: true);
        final extMetaFile = File('${extDir.path}/${building.id}.meta.json');
        await extMetaFile.writeAsString(jsonEncode(meta), flush: true);
      }
    } catch (_) {
      // Gracefully continue if external storage is inaccessible
    }
  }

  /// Loads and deserializes a building by its [id].
  Future<Building3DModel?> loadBuilding(String id, String name) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/$id.3dnav');
    if (!await file.exists()) {
      // Try restoring from external persistent backup
      try {
        final extDir = await _externalBackupDirectory;
        if (extDir != null) {
          final extFile = File('${extDir.path}/$id.3dnav');
          if (await extFile.exists()) {
            await extFile.copy(file.path);
            final extMeta = File('${extDir.path}/$id.meta.json');
            final localMeta = File('${dir.path}/$id.meta.json');
            if (await extMeta.exists()) {
              await extMeta.copy(localMeta.path);
            }
          }
        }
      } catch (_) {
        // Fallback
      }
    }

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

    try {
      final extDir = await _externalBackupDirectory;
      if (extDir != null) {
        final extFile = File('${extDir.path}/$id.3dnav');
        if (await extFile.exists()) await extFile.delete();
        final extMetaFile = File('${extDir.path}/$id.meta.json');
        if (await extMetaFile.exists()) await extMetaFile.delete();
      }
    } catch (_) {}
  }

  /// Lists all building IDs currently saved on disk, syncing from external backup if needed.
  Future<List<String>> listBuildingIds() async {
    final dir = await _mapsDirectory;
    final ids = <String>{};

    // Sync from external backup directory if present (e.g. after fresh reinstall)
    try {
      final extDir = await _externalBackupDirectory;
      if (extDir != null && await extDir.exists()) {
        final extEntities = await extDir.list().toList();
        for (final entity in extEntities) {
          if (entity is File && entity.path.endsWith('.3dnav')) {
            final filename = entity.uri.pathSegments.last;
            final id = filename.replaceAll('.3dnav', '');
            ids.add(id);

            // Restore into app local directory if missing
            final localFile = File('${dir.path}/$filename');
            if (!await localFile.exists()) {
              await entity.copy(localFile.path);
              final extMeta = File('${extDir.path}/$id.meta.json');
              final localMeta = File('${dir.path}/$id.meta.json');
              if (await extMeta.exists() && !await localMeta.exists()) {
                await extMeta.copy(localMeta.path);
              }
            }
          }
        }
      }
    } catch (_) {}

    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.3dnav')) {
        final filename = entity.uri.pathSegments.last;
        ids.add(filename.replaceAll('.3dnav', ''));
      }
    }
    return ids.toList();
  }
}
