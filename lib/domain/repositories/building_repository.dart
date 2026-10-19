import '../models/building_3d_model.dart';

/// Contract for persisting and retrieving 3D building models.
abstract class BuildingRepository {
  /// Loads all stored building models from local storage.
  Future<List<Building3DModel>> getAllBuildings();

  /// Retrieves a specific building model by [id].
  Future<Building3DModel?> getBuildingById(String id);

  /// Saves a new or modified [building] to local storage.
  Future<void> saveBuilding(Building3DModel building);

  /// Deletes a building identified by [id] from local storage.
  Future<void> deleteBuilding(String id);
}
