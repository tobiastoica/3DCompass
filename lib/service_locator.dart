import 'package:sensors_plus/sensors_plus.dart';
import 'data/datasources/binary_nav_serializer.dart';
import 'data/datasources/building_local_storage.dart';
import 'data/repositories/building_repository_impl.dart';
import 'data/repositories/navigation_repository_impl.dart';
import 'data/repositories/sensor_fusion_repository_impl.dart';
import 'data/services/arcore_canvass_service.dart';
import 'data/services/barometric_altimeter_service.dart';
import 'data/services/extended_kalman_filter.dart';
import 'data/services/faint_gps_service.dart';
import 'data/services/file_logger_service.dart';
import 'data/services/inertia_pdr_service.dart';
import 'domain/models/building_3d_model.dart';
import 'domain/models/coordinates_3d.dart';
import 'domain/models/floor_level.dart';
import 'domain/models/nav_edge.dart';
import 'domain/models/nav_graph_3d.dart';
import 'domain/models/nav_node.dart';
import 'domain/repositories/building_repository.dart';
import 'domain/repositories/navigation_repository.dart';
import 'domain/repositories/sensor_fusion_repository.dart';
import 'domain/use_cases/calibrate_entrance_use_case.dart';
import 'domain/use_cases/canvass_building_use_case.dart';
import 'domain/use_cases/compute_shortest_3d_path_use_case.dart';
import 'domain/use_cases/track_live_position_use_case.dart';
import 'ui/features/canvassing/view_models/canvassing_view_model.dart';
import 'ui/features/doorway_checkin/view_models/doorway_checkin_view_model.dart';
import 'ui/features/map_selection/view_models/map_selection_view_model.dart';
import 'ui/features/navigation/view_models/navigation_view_model.dart';

/// Central dependency injection registry for the 3D Compass application.
class ServiceLocator {
  ServiceLocator._();

  /// The singleton instance of the service locator.
  static final ServiceLocator instance = ServiceLocator._();

  // Services
  late final BinaryNavSerializer serializer;
  late final BuildingLocalStorage localStorage;
  late final BarometricAltimeterService altimeterService;
  late final InertiaPdrService pdrService;
  late final FaintGpsService gpsService;
  late final ExtendedKalmanFilter ekf;
  late final ArCoreCanvassService arCoreService;

  late final FileLoggerService logger;

  // Repositories
  late final BuildingRepository buildingRepository;
  late final SensorFusionRepository sensorFusionRepository;
  late final NavigationRepository navigationRepository;

  // Use Cases
  late final CalibrateEntranceUseCase calibrateEntranceUseCase;
  late final TrackLivePositionUseCase trackLivePositionUseCase;
  late final ComputeShortest3DPathUseCase computeShortestPathUseCase;
  late final CanvassBuildingUseCase canvassBuildingUseCase;

  /// Initializes all dependencies and seeds sample building maps if empty.
  Future<void> initialize() async {
    logger = FileLoggerService();
    await logger.initialize();

    serializer = BinaryNavSerializer();
    localStorage = BuildingLocalStorage(serializer: serializer);
    final pressureStream = barometerEventStream()
        .map((e) => e.pressure)
        .handleError((error) {
      logger.log(LogLevel.error, 'BAROMETER', error.toString());
    });
    altimeterService = BarometricAltimeterService(pressureStream: pressureStream);
    pdrService = InertiaPdrService();
    gpsService = FaintGpsService();
    ekf = ExtendedKalmanFilter();
    arCoreService = ArCoreCanvassService();

    buildingRepository = BuildingRepositoryImpl(localStorage: localStorage);
    sensorFusionRepository = SensorFusionRepositoryImpl(
      altimeterService: altimeterService,
      pdrService: pdrService,
      gpsService: gpsService,
      ekf: ekf,
      logger: logger,
    );
    navigationRepository = NavigationRepositoryImpl();

    calibrateEntranceUseCase = CalibrateEntranceUseCase(
      sensorFusionRepository: sensorFusionRepository,
    );
    trackLivePositionUseCase = TrackLivePositionUseCase(
      sensorFusionRepository: sensorFusionRepository,
    );
    computeShortestPathUseCase = const ComputeShortest3DPathUseCase();
    canvassBuildingUseCase = CanvassBuildingUseCase(
      buildingRepository: buildingRepository,
    );

    await _seedSampleBuildingIfEmpty();
  }

  /// Creates a [DoorwayCheckinViewModel].
  DoorwayCheckinViewModel createDoorwayCheckinViewModel() {
    return DoorwayCheckinViewModel(
      calibrateEntranceUseCase: calibrateEntranceUseCase,
    );
  }

  /// Creates a [NavigationViewModel].
  NavigationViewModel createNavigationViewModel() {
    return NavigationViewModel(
      navigationRepository: navigationRepository,
      sensorFusionRepository: sensorFusionRepository,
      trackLivePositionUseCase: trackLivePositionUseCase,
      computeShortestPathUseCase: computeShortestPathUseCase,
    );
  }

  /// Creates a [CanvassingViewModel].
  CanvassingViewModel createCanvassingViewModel() {
    return CanvassingViewModel(
      canvassBuildingUseCase: canvassBuildingUseCase,
      trackLivePositionUseCase: trackLivePositionUseCase,
      arCoreService: arCoreService,
    );
  }

  /// Creates a [MapSelectionViewModel].
  MapSelectionViewModel createMapSelectionViewModel() {
    return MapSelectionViewModel(
      buildingRepository: buildingRepository,
      navigationRepository: navigationRepository,
    );
  }

  Future<void> _seedSampleBuildingIfEmpty() async {
    final existing = await buildingRepository.getAllBuildings();
    if (existing.isNotEmpty) return;

    // Seed a realistic 3-floor sample building
    final floors = [
      const FloorLevel(floorIndex: 0, name: 'Ground Floor', baseElevationMeters: 0.0, floorHeightMeters: 3.6),
      const FloorLevel(floorIndex: 1, name: 'First Floor', baseElevationMeters: 3.6, floorHeightMeters: 3.6),
      const FloorLevel(floorIndex: 2, name: 'Second Floor', baseElevationMeters: 7.2, floorHeightMeters: 3.6),
    ];

    final nodes = <String, NavNode>{
      'entrance_main': const NavNode(id: 'entrance_main', name: 'Main Entrance Doorway', position: Coordinates3D(x: 0, y: 0, z: 0), floorIndex: 0, type: NodeType.doorway),
      'hallway_f0_1': const NavNode(id: 'hallway_f0_1', name: 'Ground Main Hall', position: Coordinates3D(x: 10, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
      'room_f0_101': const NavNode(id: 'room_f0_101', name: 'Room 101 (Auditorium)', position: Coordinates3D(x: 10, y: 15, z: 0), floorIndex: 0, type: NodeType.room),
      'stairs_f0': const NavNode(id: 'stairs_f0', name: 'Central Stairwell (F0)', position: Coordinates3D(x: 20, y: 0, z: 0), floorIndex: 0, type: NodeType.stairs),
      
      'stairs_f1': const NavNode(id: 'stairs_f1', name: 'Central Stairwell (F1)', position: Coordinates3D(x: 20, y: 0, z: 3.6), floorIndex: 1, type: NodeType.stairs),
      'hallway_f1_1': const NavNode(id: 'hallway_f1_1', name: 'Floor 1 Atrium Hall', position: Coordinates3D(x: 10, y: 0, z: 3.6), floorIndex: 1, type: NodeType.hallway),
      'room_f1_201': const NavNode(id: 'room_f1_201', name: 'Room 201 (Library)', position: Coordinates3D(x: 10, y: 15, z: 3.6), floorIndex: 1, type: NodeType.room),
      
      'stairs_f2': const NavNode(id: 'stairs_f2', name: 'Central Stairwell (F2)', position: Coordinates3D(x: 20, y: 0, z: 7.2), floorIndex: 2, type: NodeType.stairs),
      'room_f2_301': const NavNode(id: 'room_f2_301', name: 'Room 301 (Robotics Lab)', position: Coordinates3D(x: 10, y: 15, z: 7.2), floorIndex: 2, type: NodeType.room),
    };

    final edges = <NavEdge>[
      const NavEdge(sourceNodeId: 'entrance_main', targetNodeId: 'hallway_f0_1', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'hallway_f0_1', targetNodeId: 'room_f0_101', distanceMeters: 15.0),
      const NavEdge(sourceNodeId: 'hallway_f0_1', targetNodeId: 'stairs_f0', distanceMeters: 10.0),
      // Vertical stairs connection F0 -> F1
      const NavEdge(sourceNodeId: 'stairs_f0', targetNodeId: 'stairs_f1', distanceMeters: 5.0, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      const NavEdge(sourceNodeId: 'stairs_f1', targetNodeId: 'hallway_f1_1', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'hallway_f1_1', targetNodeId: 'room_f1_201', distanceMeters: 15.0),
      // Vertical stairs connection F1 -> F2
      const NavEdge(sourceNodeId: 'stairs_f1', targetNodeId: 'stairs_f2', distanceMeters: 5.0, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      const NavEdge(sourceNodeId: 'stairs_f2', targetNodeId: 'room_f2_301', distanceMeters: 18.0),
    ];

    final sampleBuilding = Building3DModel(
      id: 'science_hall',
      name: 'Science Complex',
      floors: floors,
      navGraph: NavGraph3D(nodes: nodes, edges: edges),
      entranceAnchors: [nodes['entrance_main']!],
      createdAt: DateTime.now(),
    );

    await buildingRepository.saveBuilding(sampleBuilding);
  }
}
