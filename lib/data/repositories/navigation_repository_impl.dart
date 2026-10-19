import '../../domain/models/building_3d_model.dart';
import '../../domain/models/navigation_path.dart';
import '../../domain/repositories/navigation_repository.dart';

/// Implements [NavigationRepository] for tracking the active building and route session.
class NavigationRepositoryImpl implements NavigationRepository {
  /// Creates a navigation repository.
  NavigationRepositoryImpl();

  Building3DModel? _activeBuilding;
  NavigationPath? _activePath;

  @override
  Building3DModel? get activeBuilding => _activeBuilding;

  @override
  void setActiveBuilding(Building3DModel building) {
    _activeBuilding = building;
    _activePath = null;
  }

  @override
  NavigationPath? get activePath => _activePath;

  @override
  void setActivePath(NavigationPath? path) {
    _activePath = path;
  }
}
