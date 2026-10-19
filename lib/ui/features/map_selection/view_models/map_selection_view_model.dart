import 'package:flutter/foundation.dart';
import '../../../domain/models/building_3d_model.dart';
import '../../../domain/repositories/building_repository.dart';
import '../../../domain/repositories/navigation_repository.dart';

/// Manages building map listing and selection.
class MapSelectionViewModel extends ChangeNotifier {
  /// Creates a map selection view model.
  MapSelectionViewModel({
    required BuildingRepository buildingRepository,
    required NavigationRepository navigationRepository,
  })  : _buildingRepository = buildingRepository,
        _navigationRepository = navigationRepository;

  final BuildingRepository _buildingRepository;
  final NavigationRepository _navigationRepository;

  List<Building3DModel> _buildings = [];
  bool _isLoading = false;

  /// The list of available preloaded or surveyed building models.
  List<Building3DModel> get buildings => _buildings;

  /// Whether buildings are currently loading from disk.
  bool get isLoading => _isLoading;

  /// Loads all stored building models from the repository.
  Future<void> loadBuildings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _buildings = await _buildingRepository.getAllBuildings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the selected [building] as active for navigation.
  void selectBuilding(Building3DModel building) {
    _navigationRepository.setActiveBuilding(building);
  }
}
