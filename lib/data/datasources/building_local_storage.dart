import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/building_3d_model.dart';
import 'binary_nav_serializer.dart';

/// Manages filesystem persistence of `.3dnav` building models in local storage.
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

  /// Writes [building] as a binary `.3dnav` file to local storage.
  Future<void> saveBuilding(Building3DModel building) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/${building.id}.3dnav');

    final bytes = _serializer.serialize(
      graph: building.navGraph,
      floors: building.floors,
    );

    await file.writeAsBytes(bytes, flush: true);
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

    return Building3DModel(
      id: id,
      name: name,
      floors: decoded.floors,
      navGraph: decoded.graph,
      entranceAnchors: decoded.graph.nodes.values
          .where((n) => n.type.name == 'doorway')
          .toList(),
    );
  }

  /// Deletes the `.3dnav` file associated with [id].
  Future<void> deleteBuilding(String id) async {
    final dir = await _mapsDirectory;
    final file = File('${dir.path}/$id.3dnav');
    if (await file.exists()) {
      await file.delete();
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
