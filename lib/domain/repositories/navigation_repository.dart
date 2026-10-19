import '../models/building_3d_model.dart';
import '../models/navigation_path.dart';

/// Contract for managing active navigation sessions.
abstract class NavigationRepository {
  /// The active building model currently being navigated.
  Building3DModel? get activeBuilding;

  /// Sets the current active building to [building].
  void setActiveBuilding(Building3DModel building);

  /// The active navigation path, or `null` if no destination is selected.
  NavigationPath? get activePath;

  /// Sets the active navigation route to [path].
  void setActivePath(NavigationPath? path);
}
