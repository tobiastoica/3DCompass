import '../../domain/models/building_3d_model.dart';
import '../../domain/repositories/building_repository.dart';
import '../datasources/building_local_storage.dart';

/// Implements [BuildingRepository] using local filesystem `.3dnav` persistence.
class BuildingRepositoryImpl implements BuildingRepository {
  /// Creates a building repository implementation.
  BuildingRepositoryImpl({
    required BuildingLocalStorage localStorage,
  }) : _localStorage = localStorage;

  final BuildingLocalStorage _localStorage;
  final Map<String, Building3DModel> _memoryCache = {};

  @override
  Future<List<Building3DModel>> getAllBuildings() async {
    final ids = await _localStorage.listBuildingIds();
    final list = <Building3DModel>[];

    for (final id in ids) {
      if (_memoryCache.containsKey(id)) {
        list.add(_memoryCache[id]!);
      } else {
        final loaded = await _localStorage.loadBuilding(id, id.replaceAll('_', ' '));
        if (loaded != null) {
          _memoryCache[id] = loaded;
          list.add(loaded);
        }
      }
    }

    return list;
  }

  @override
  Future<Building3DModel?> getBuildingById(String id) async {
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }
    final loaded = await _localStorage.loadBuilding(id, id.replaceAll('_', ' '));
    if (loaded != null) {
      _memoryCache[id] = loaded;
    }
    return loaded;
  }

  @override
  Future<void> saveBuilding(Building3DModel building) async {
    _memoryCache[building.id] = building;
    await _localStorage.saveBuilding(building);
  }

  @override
  Future<void> deleteBuilding(String id) async {
    _memoryCache.remove(id);
    await _localStorage.deleteBuilding(id);
  }
}
