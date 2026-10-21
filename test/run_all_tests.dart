import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../lib/data/datasources/binary_nav_serializer.dart';
import '../lib/data/services/barometric_altimeter_service.dart';
import '../lib/data/services/extended_kalman_filter.dart';
import '../lib/data/services/file_logger_service.dart';
import '../lib/domain/models/coordinates_3d.dart';
import '../lib/domain/models/floor_level.dart';
import '../lib/domain/models/nav_edge.dart';
import '../lib/domain/models/nav_graph_3d.dart';
import '../lib/domain/models/nav_node.dart';
import '../lib/domain/models/navigation_path.dart';
import '../lib/domain/use_cases/compute_shortest_3d_path_use_case.dart';

Future<void> main() async {
  print('================================================================');
  print('    RUNNING 3D COMPASS INDOOR NAVIGATION TEST SUITE (PURE DART)  ');
  print('================================================================\n');

  var passedCount = 0;
  var failedCount = 0;

  Future<void> runTest(String name, FutureOr<void> Function() testBody) async {
    try {
      final stopwatch = Stopwatch()..start();
      await testBody();
      stopwatch.stop();
      print(' [PASS] $name (${stopwatch.elapsedMicroseconds} us)');
      passedCount++;
    } catch (e, stack) {
      print(' [FAIL] $name');
      print('        Error: $e');
      print('        Stack: $stack');
      failedCount++;
    }
  }

  void expect(bool condition, String message) {
    if (!condition) {
      throw AssertionError('Assertion failed: $message');
    }
  }

  void expectCloseTo(double actual, double expected, double delta, String label) {
    if ((actual - expected).abs() > delta) {
      throw AssertionError('$label: Expected $expected +/- $delta, but got $actual');
    }
  }

  // =========================================================================
  // 1. BINARY .3DNAV SERIALIZER TESTS
  // =========================================================================
  print('--- 1. Testing Binary .3dnav Serializer & Deserializer ---');

  runTest('Serializes and deserializes multi-floor building graph with sub-millimeter precision', () {
    final serializer = BinaryNavSerializer();
    final floors = [
      const FloorLevel(floorIndex: 0, name: 'Ground', baseElevationMeters: 0.0, floorHeightMeters: 3.6),
      const FloorLevel(floorIndex: 1, name: 'First', baseElevationMeters: 3.6, floorHeightMeters: 3.6),
      const FloorLevel(floorIndex: 2, name: 'Second', baseElevationMeters: 7.2, floorHeightMeters: 3.6),
    ];

    final nodes = <String, NavNode>{
      'n1': const NavNode(id: 'n1', name: 'Entrance', position: Coordinates3D(x: 12.345, y: -67.890, z: 0.0), floorIndex: 0, type: NodeType.doorway),
      'n2': const NavNode(id: 'n2', name: 'Atrium', position: Coordinates3D(x: 35.120, y: 14.500, z: 3.6), floorIndex: 1, type: NodeType.hallway),
      'n3': const NavNode(id: 'n3', name: 'Lab 301', position: Coordinates3D(x: 45.000, y: 22.000, z: 7.2), floorIndex: 2, type: NodeType.room),
    };

    final edges = <NavEdge>[
      const NavEdge(sourceNodeId: 'n1', targetNodeId: 'n2', distanceMeters: 25.5, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      const NavEdge(sourceNodeId: 'n2', targetNodeId: 'n3', distanceMeters: 18.2, transitionType: VerticalTransition.elevator, isWheelchairAccessible: true),
    ];

    final originalGraph = NavGraph3D(nodes: nodes, edges: edges);

    // Measure serialization
    final bytes = serializer.serialize(graph: originalGraph, floors: floors);
    expect(bytes.isNotEmpty, 'Bytes should not be empty');

    // Verify magic header: "3DNV" in little endian is [0x33, 0x44, 0x4E, 0x56]
    expect(bytes[0] == 0x33 && bytes[1] == 0x44 && bytes[2] == 0x4E && bytes[3] == 0x56, 'Magic header must match 3DNV');

    // Measure deserialization speed
    final sw = Stopwatch()..start();
    final decoded = serializer.deserialize(bytes);
    sw.stop();
    expect(sw.elapsedMilliseconds < 5, 'Deserialization took ${sw.elapsedMilliseconds}ms, must be < 5ms');

    expect(decoded.floors.length == 3, 'Floor count must match 3');
    expectCloseTo(decoded.floors[1].baseElevationMeters, 3.6, 0.001, 'Floor 1 elevation');
    expectCloseTo(decoded.floors[2].baseElevationMeters, 7.2, 0.001, 'Floor 2 elevation');

    expect(decoded.graph.nodes.length == 3, 'Node count must match 3');
    final decodedEntrance = decoded.graph.nodes.values.firstWhere((n) => (n.position.x - 12.345).abs() < 0.001);
    expectCloseTo(decodedEntrance.position.y, -67.890, 0.001, 'Entrance Y coordinate');

    expect(decoded.graph.allEdges.length == 2, 'Edge count must match 2');
    expect(decoded.graph.allEdges[0].transitionType == VerticalTransition.stairs, 'Edge 0 transition must be stairs');
    expect(decoded.graph.allEdges[1].isWheelchairAccessible == true, 'Edge 1 must be wheelchair accessible');
  });

  runTest('Rejects corrupt binary buffer with invalid magic header', () {
    final serializer = BinaryNavSerializer();
    final corrupted = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
    var caught = false;
    try {
      serializer.deserialize(corrupted);
    } catch (e) {
      caught = true;
    }
    expect(caught, 'Corrupted header must throw FormatException');
  });

  // =========================================================================
  // 2. OFFLINE BAROMETRIC ALTIMETRY TESTS
  // =========================================================================
  print('\n--- 2. Testing Offline Barometric Altimeter Service ---');

  runTest('Latching baseline establishes zero reference at entrance datum', () {
    final altimeter = BarometricAltimeterService();
    altimeter.latchBaseline(1013.25);
    expect(altimeter.isCalibrated == true, 'Altimeter should be calibrated');
    expect(altimeter.entrancePressureHpa == 1013.25, 'Baseline pressure should be 1013.25 hPa');

    final z0 = altimeter.calculateRelativeAltitude(1013.25);
    expectCloseTo(z0, 0.0, 0.001, 'Altitude at baseline pressure must be 0.0m');
  });

  runTest('Calculates accurate vertical elevations from pressure drops', () {
    final altimeter = BarometricAltimeterService();
    altimeter.latchBaseline(1013.25);

    // Dropping ~1.2 hPa represents ~10 meters
    final z10m = altimeter.calculateRelativeAltitude(1012.0);
    expect(z10m > 9.5 && z10m < 11.5, 'Altitude at 1012 hPa should be ~10.4m, was $z10m');

    // Dropping to 1000 hPa represents ~110.8 meters
    final z110m = altimeter.calculateRelativeAltitude(1000.0);
    expectCloseTo(z110m, 110.8, 1.5, 'Altitude at 1000 hPa');
  });

  runTest('Classifies floor indices accurately with height intervals', () {
    final altimeter = BarometricAltimeterService();
    expect(altimeter.estimateFloorIndex(0.0, floorHeightMeters: 3.6) == 0, '0m is Floor 0');
    expect(altimeter.estimateFloorIndex(3.6, floorHeightMeters: 3.6) == 1, '3.6m is Floor 1');
    expect(altimeter.estimateFloorIndex(7.2, floorHeightMeters: 3.6) == 2, '7.2m is Floor 2');
    expect(altimeter.estimateFloorIndex(10.8, floorHeightMeters: 3.6) == 3, '10.8m is Floor 3');
    expect(altimeter.estimateFloorIndex(-3.6, floorHeightMeters: 3.6) == -1, '-3.6m is Basement -1');
  });

  runTest('Automatically detects floor ascent at >2.0m rise and recalibrates on return', () {
    final altimeter = BarometricAltimeterService();
    altimeter.latchBaseline(1008.79);

    expect(altimeter.activeFloorIndex == 0, 'Starts on floor 0');

    // Small hand fluctuation of 0.8m remains Floor 0
    altimeter.calculateRelativeAltitude(1008.69);
    expect(altimeter.activeFloorIndex == 0, '0.8m is still Floor 0');

    // Climbing stairs past +2.0m (pressure drops to 1008.45 hPa -> ~2.8m rise)
    altimeter.calculateRelativeAltitude(1008.45);
    expect(altimeter.activeFloorIndex == 1, 'Climbing >2m switches to Floor 1');

    // Reaching Floor 1 landing at +4.0m (1008.28 hPa)
    altimeter.calculateRelativeAltitude(1008.28);
    expect(altimeter.activeFloorIndex == 1, 'Floor 1 maintained');

    // Descending stairs back towards Floor 0 (pressure rises back to 1008.75 hPa)
    altimeter.calculateRelativeAltitude(1008.75);
    expect(altimeter.activeFloorIndex == 0, 'Descent below -2m threshold switches back to Floor 0');
    expectCloseTo(altimeter.entrancePressureHpa!, 1008.75, 0.001, 'Floor 0 datum reset on descent return');
  });

  // =========================================================================
  // 3. 3D A* MULTI-FLOOR PATHFINDING TESTS
  // =========================================================================
  print('\n--- 3. Testing 3D Multi-Floor A* Pathfinding ---');

  runTest('Finds optimal 3D path across floors traversing stairwells', () {
    const useCase = ComputeShortest3DPathUseCase();

    final nodes = <String, NavNode>{
      'f0_room_a': const NavNode(id: 'f0_room_a', name: 'Room A', position: Coordinates3D(x: 0, y: 0, z: 0), floorIndex: 0, type: NodeType.room),
      'f0_hall': const NavNode(id: 'f0_hall', name: 'F0 Hall', position: Coordinates3D(x: 10, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
      'f0_stairs': const NavNode(id: 'f0_stairs', name: 'F0 Stairs', position: Coordinates3D(x: 20, y: 0, z: 0), floorIndex: 0, type: NodeType.stairs),
      'f0_elevator': const NavNode(id: 'f0_elevator', name: 'F0 Elevator', position: Coordinates3D(x: 10, y: 15, z: 0), floorIndex: 0, type: NodeType.elevator),

      'f1_stairs': const NavNode(id: 'f1_stairs', name: 'F1 Stairs', position: Coordinates3D(x: 20, y: 0, z: 3.6), floorIndex: 1, type: NodeType.stairs),
      'f1_elevator': const NavNode(id: 'f1_elevator', name: 'F1 Elevator', position: Coordinates3D(x: 10, y: 15, z: 3.6), floorIndex: 1, type: NodeType.elevator),
      'f1_hall': const NavNode(id: 'f1_hall', name: 'F1 Hall', position: Coordinates3D(x: 10, y: 0, z: 3.6), floorIndex: 1, type: NodeType.hallway),
      'f1_room_b': const NavNode(id: 'f1_room_b', name: 'Room B', position: Coordinates3D(x: 0, y: 0, z: 3.6), floorIndex: 1, type: NodeType.room),
    };

    final edges = <NavEdge>[
      const NavEdge(sourceNodeId: 'f0_room_a', targetNodeId: 'f0_hall', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_stairs', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_elevator', distanceMeters: 15.0),

      const NavEdge(sourceNodeId: 'f0_stairs', targetNodeId: 'f1_stairs', distanceMeters: 5.0, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      const NavEdge(sourceNodeId: 'f0_elevator', targetNodeId: 'f1_elevator', distanceMeters: 5.0, transitionType: VerticalTransition.elevator, isWheelchairAccessible: true),

      const NavEdge(sourceNodeId: 'f1_stairs', targetNodeId: 'f1_hall', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f1_elevator', targetNodeId: 'f1_hall', distanceMeters: 15.0),
      const NavEdge(sourceNodeId: 'f1_hall', targetNodeId: 'f1_room_b', distanceMeters: 10.0),
    ];

    final graph = NavGraph3D(nodes: nodes, edges: edges);

    // Standard routing via stairs
    final path = useCase.execute(
      graph: graph,
      startNodeId: 'f0_room_a',
      targetNodeId: 'f1_room_b',
    );

    expect(path.isNotEmpty, 'Path must not be empty');
    expect(path.startNode?.id == 'f0_room_a', 'Start node must be f0_room_a');
    expect(path.destinationNode?.id == 'f1_room_b', 'Destination node must be f1_room_b');
    final ids = path.waypoints.map((w) => w.id).toList();
    expect(ids.contains('f0_stairs'), 'Must use stairs when standard');
  });

  runTest('Wheelchair accessible mode routes strictly via elevators', () {
    const useCase = ComputeShortest3DPathUseCase();

    final nodes = <String, NavNode>{
      'f0_room_a': const NavNode(id: 'f0_room_a', name: 'Room A', position: Coordinates3D(x: 0, y: 0, z: 0), floorIndex: 0, type: NodeType.room),
      'f0_hall': const NavNode(id: 'f0_hall', name: 'F0 Hall', position: Coordinates3D(x: 10, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
      'f0_stairs': const NavNode(id: 'f0_stairs', name: 'F0 Stairs', position: Coordinates3D(x: 20, y: 0, z: 0), floorIndex: 0, type: NodeType.stairs),
      'f0_elevator': const NavNode(id: 'f0_elevator', name: 'F0 Elevator', position: Coordinates3D(x: 10, y: 15, z: 0), floorIndex: 0, type: NodeType.elevator),

      'f1_stairs': const NavNode(id: 'f1_stairs', name: 'F1 Stairs', position: Coordinates3D(x: 20, y: 0, z: 3.6), floorIndex: 1, type: NodeType.stairs),
      'f1_elevator': const NavNode(id: 'f1_elevator', name: 'F1 Elevator', position: Coordinates3D(x: 10, y: 15, z: 3.6), floorIndex: 1, type: NodeType.elevator),
      'f1_hall': const NavNode(id: 'f1_hall', name: 'F1 Hall', position: Coordinates3D(x: 10, y: 0, z: 3.6), floorIndex: 1, type: NodeType.hallway),
      'f1_room_b': const NavNode(id: 'f1_room_b', name: 'Room B', position: Coordinates3D(x: 0, y: 0, z: 3.6), floorIndex: 1, type: NodeType.room),
    };

    final edges = <NavEdge>[
      const NavEdge(sourceNodeId: 'f0_room_a', targetNodeId: 'f0_hall', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_stairs', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_elevator', distanceMeters: 15.0),

      const NavEdge(sourceNodeId: 'f0_stairs', targetNodeId: 'f1_stairs', distanceMeters: 5.0, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      const NavEdge(sourceNodeId: 'f0_elevator', targetNodeId: 'f1_elevator', distanceMeters: 5.0, transitionType: VerticalTransition.elevator, isWheelchairAccessible: true),

      const NavEdge(sourceNodeId: 'f1_stairs', targetNodeId: 'f1_hall', distanceMeters: 10.0),
      const NavEdge(sourceNodeId: 'f1_elevator', targetNodeId: 'f1_hall', distanceMeters: 15.0),
      const NavEdge(sourceNodeId: 'f1_hall', targetNodeId: 'f1_room_b', distanceMeters: 10.0),
    ];

    final graph = NavGraph3D(nodes: nodes, edges: edges);

    final path = useCase.execute(
      graph: graph,
      startNodeId: 'f0_room_a',
      targetNodeId: 'f1_room_b',
      requireElevatorOnly: true,
    );

    final ids = path.waypoints.map((w) => w.id).toList();
    expect(ids.contains('f0_elevator'), 'Must traverse elevator');
    expect(!ids.contains('f0_stairs'), 'Must NOT traverse stairs when wheelchair mode is on');
  });

  runTest('getNextWaypoint guides forward along path without backward flipping', () {
    final path = NavigationPath(waypoints: [
      const NavNode(id: 'w0', name: 'Start', position: Coordinates3D(x: 0, y: 0, z: 0), floorIndex: 0, type: NodeType.doorway),
      const NavNode(id: 'w1', name: 'Corridor 1', position: Coordinates3D(x: 10, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
      const NavNode(id: 'w2', name: 'Corridor 2', position: Coordinates3D(x: 20, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
      const NavNode(id: 'w3', name: 'Room 101', position: Coordinates3D(x: 30, y: 0, z: 0), floorIndex: 0, type: NodeType.room),
    ]);

    // User at start (0, 0)
    expect(path.getNextWaypoint(const Coordinates3D(x: 0, y: 0, z: 0))?.id == 'w1', 'At start, points forward to w1');

    // User walks halfway to w1 at (5, 0) - MUST NOT flip backward to w0!
    expect(path.getNextWaypoint(const Coordinates3D(x: 5, y: 0, z: 0))?.id == 'w1', 'Mid-corridor, still points forward to w1');

    // User reaches w1 at (10, 0)
    expect(path.getNextWaypoint(const Coordinates3D(x: 10, y: 0, z: 0))?.id == 'w2', 'At w1, advances forward to w2');

    // User between w1 and w2 at (15, 0)
    expect(path.getNextWaypoint(const Coordinates3D(x: 15, y: 0, z: 0))?.id == 'w2', 'Advances forward to w2');

    // User reaches destination at (30, 0)
    expect(path.getNextWaypoint(const Coordinates3D(x: 30, y: 0, z: 0))?.id == 'w3', 'At destination, target is w3');
  });

  // =========================================================================
  // 4. EXTENDED KALMAN FILTER (EKF) SENSOR FUSION TESTS
  // =========================================================================
  print('\n--- 4. Testing 7-State Extended Kalman Filter Sensor Fusion ---');

  runTest('Initializes at doorway datum and propagates PDR steps along azimuth', () {
    final ekf = ExtendedKalmanFilter();
    expect(ekf.position.x == 0.0, 'Initial X is 0.0');
    expect(ekf.position.y == 0.0, 'Initial Y is 0.0');
    expect(ekf.position.z == 0.0, 'Initial Z is 0.0');

    // Step 1: 0.75m heading East (heading = 0 rad)
    ekf.predictStep(stepLengthMeters: 0.75, measuredHeadingRadians: 0.0);
    expectCloseTo(ekf.position.x, 0.75, 0.01, 'X after East step');
    expectCloseTo(ekf.position.y, 0.0, 0.01, 'Y after East step');

    // Step 2: 0.75m heading North (heading = pi/2 rad)
    ekf.predictStep(stepLengthMeters: 0.75, measuredHeadingRadians: math.pi / 2.0);
    expect(ekf.position.x > 0.7, 'X retained');
    expect(ekf.position.y > 0.4, 'Y displaced North');
  });

  runTest('Barometer vertical updates contract variance and track elevation', () {
    final ekf = ExtendedKalmanFilter();
    // Simulate incoming stream of barometer updates
    for (var i = 0; i < 3; i++) {
      ekf.updateBarometerAltitude(3.6);
    }
    expect(ekf.position.z > 2.8, 'Elevation should update toward 3.6m');

    // Repeated measurements converge
    for (var i = 0; i < 5; i++) {
      ekf.updateBarometerAltitude(3.6);
    }
    expectCloseTo(ekf.position.z, 3.6, 0.05, 'Elevation must converge to 3.6m');
  });

  runTest('Fuses faint GNSS fixes within gate and rejects multipath spikes', () {
    final ekf = ExtendedKalmanFilter();
    ekf.predictStep(stepLengthMeters: 1.0, measuredHeadingRadians: 0.0);

    // Faint GNSS measurement (accuracy = 18m <= 35m gate) gently pulls state
    ekf.updateGpsFix(localX: 0.95, localY: 0.05, accuracyMeters: 18.0);
    expect(ekf.position.x > 0.9 && ekf.position.x < 1.05, 'Faint GPS fix incorporated');

    // Multipath outlier (accuracy = 80m > 35m) must be rejected
    final xBefore = ekf.position.x;
    ekf.updateGpsFix(localX: 50.0, localY: 50.0, accuracyMeters: 80.0);
    expect(ekf.position.x == xBefore, 'Outlier must be rejected completely');
  });

  // =========================================================================
  // 5. 3D COMPASS VECTOR MATH & BEARING CALCULATION
  // =========================================================================
  print('\n--- 5. Testing 3D Compass Math & Vector Transforms ---');

  runTest('Computes accurate bearing and vertical pitch tilt to target on upper floor', () {
    const userPos = Coordinates3D(x: 0, y: 0, z: 0);
    const targetOnFloor2 = Coordinates3D(x: 10, y: 10, z: 7.2);

    final dx = targetOnFloor2.x - userPos.x;
    final dy = targetOnFloor2.y - userPos.y;
    final dz = targetOnFloor2.z - userPos.z;

    // Azimuth bearing
    final bearingRad = math.atan2(dy, dx);
    final bearingDeg = bearingRad * 180.0 / math.pi;
    expectCloseTo(bearingDeg, 45.0, 0.1, '45 degrees bearing');

    // Elevation pitch angle
    final horizontalDist = math.sqrt(dx * dx + dy * dy); // ~14.14m
    final pitchRad = math.atan2(dz, horizontalDist);
    final pitchDeg = pitchRad * 180.0 / math.pi;
    expectCloseTo(pitchDeg, 27.0, 0.5, '27 degrees upwards pitch tilt');
  });

  // =========================================================================
  // 6. PERSISTENT FILE LOGGER TESTS (DOWNLOADS DIRECTORY LOGGING)
  // =========================================================================
  print('\n--- 6. Testing File Logger Service (Downloads Telemetry Logging) ---');

  await runTest('Initializes log file on disk and writes structured telemetry entries', () async {
    final tempDir = Directory.systemTemp.createTempSync('compass_test_logs');
    final logger = FileLoggerService(customLogDirectory: tempDir.path);

    // Initial log before initialize
    logger.log(LogLevel.info, 'BOOT', 'Testing pre-initialization buffering');

    // Initialize logger
    final logPath = await logger.initialize();
    expect(logPath.isNotEmpty, 'Log path must be valid');
    expect(logger.isInitialized == true, 'Logger must be initialized');

    // Write all telemetry event types
    logger.logDoorwayCheckin(
      entranceId: 'door_north_1',
      entranceName: 'North Gate Doorway',
      baselinePressureHpa: 1012.45,
    );

    logger.logPdrStep(
      stepLengthMeters: 0.76,
      headingDegrees: 48.5,
      posX: 12.4,
      posY: 8.2,
      posZ: 3.6,
    );

    logger.logBarometerUpdate(
      currentPressureHpa: 1012.01,
      relativeAltitudeMeters: 3.65,
      floorIndex: 1,
    );

    logger.logGpsFix(
      latitude: 47.1234,
      longitude: 8.5678,
      accuracyMeters: 14.2,
      isAccepted: true,
    );

    logger.logRouteComputed(
      startNodeId: 'entrance',
      targetNodeId: 'lab_301',
      totalDistanceMeters: 45.2,
      waypointCount: 6,
      elapsedMicroseconds: 2150,
    );

    await logger.dispose();

    // Verify file content on disk
    final logFile = File(logger.activeLogFilePath!);
    expect(logFile.existsSync() == true, 'Log file must exist on disk');

    final content = logFile.readAsStringSync();
    expect(content.contains('[DOORWAY]'), 'Must contain [DOORWAY] entry');
    expect(content.contains('[PDR]'), 'Must contain [PDR] entry');
    expect(content.contains('[BARO]'), 'Must contain [BARO] entry');
    expect(content.contains('[GNSS]'), 'Must contain [GNSS] entry');
    expect(content.contains('[ROUTE]'), 'Must contain [ROUTE] entry');
    expect(content.contains('North Gate Doorway'), 'Must contain entrance name');
    expect(content.contains('1012.45hPa'), 'Must contain baseline pressure');

    // Cleanup temp directory
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  print('\n--- 7. Testing Gyroscope Gravity Projection & 90-Degree Turn Tracking ---');

  await runTest('Accurately tracks 90-degree left and right turns across different phone tilt angles', () {
    // Case 1: Phone held flat (screen up, gravity reaction along +Z)
    var upX = 0.0, upY = 0.0, upZ = 1.0;
    var heading = 0.0; // East

    // User turns 90 degrees left over 1.0s with gyro.z = pi/2 rad/s
    var gx = 0.0, gy = 0.0, gz = math.pi / 2.0;
    var dt = 1.0;
    var omegaVert = gx * upX + gy * upY + gz * upZ;
    heading += omegaVert * dt;
    expectCloseTo(heading, math.pi / 2.0, 1e-4, 'Heading after flat 90 deg left turn');

    // Case 2: Phone held in portrait upright (AR scanning, top +Y points up)
    upX = 0.0; upY = 1.0; upZ = 0.0;
    heading = 0.0;
    // Turning 90 degrees left rotates around +Y with gyro.y = pi/2 rad/s
    gx = 0.0; gy = math.pi / 2.0; gz = 0.0;
    omegaVert = gx * upX + gy * upY + gz * upZ;
    heading += omegaVert * dt;
    expectCloseTo(heading, math.pi / 2.0, 1e-4, 'Heading after upright 90 deg left turn');

    // Case 3: Phone tilted at 45 degrees
    final invSqrt2 = 1.0 / math.sqrt(2.0);
    upX = 0.0; upY = invSqrt2; upZ = invSqrt2;
    heading = 0.0;
    // Turning 90 deg left splits rate equally between Y and Z
    final component = (math.pi / 2.0) * invSqrt2;
    gx = 0.0; gy = component; gz = component;
    omegaVert = gx * upX + gy * upY + gz * upZ;
    heading += omegaVert * dt;
    expectCloseTo(heading, math.pi / 2.0, 1e-4, 'Heading after 45-deg tilted 90 deg left turn');

    // Verify displacement steps now trace a U-shape:
    // Step 1: North (dy = 5, dx = 0)
    // Step 2: Turn Left to West (dx = -5, dy = 0)
    // Step 3: Turn Left to South (dy = -5, dx = 0)
    final h1 = math.pi / 2.0; // North
    final h2 = math.pi; // West
    final h3 = -math.pi / 2.0; // South

    var px = 0.0, py = 0.0;
    px += 5.0 * math.cos(h1);
    py += 5.0 * math.sin(h1);
    expectCloseTo(px, 0.0, 1e-4, 'U-turn step 1 X');
    expectCloseTo(py, 5.0, 1e-4, 'U-turn step 1 Y');

    px += 5.0 * math.cos(h2);
    py += 5.0 * math.sin(h2);
    expectCloseTo(px, -5.0, 1e-4, 'U-turn step 2 X');
    expectCloseTo(py, 5.0, 1e-4, 'U-turn step 2 Y');

    px += 5.0 * math.cos(h3);
    py += 5.0 * math.sin(h3);
    expectCloseTo(px, -5.0, 1e-4, 'U-turn step 3 X');
    expectCloseTo(py, 0.0, 1e-4, 'U-turn step 3 Y (returned to starting Y baseline)');
  });

  print('\n--- 8. Testing Corridor Wall Bounding & Landmark Snapping ---');

  await runTest('Snaps to landmark when within 1.2m and clamps to corridor bounds when drifting', () {
    final landmark = Coordinates3D(x: 10.0, y: 10.0, z: 0.0);

    // Test 1: User is 0.5m away from landmark -> should snap to landmark position
    final rawNear = Coordinates3D(x: 10.3, y: 10.4, z: 0.0);
    final distToLandmark = rawNear.horizontalDistanceTo(landmark);
    expect(distToLandmark < 1.2, 'Distance must be < 1.2m for snap');
    final snapped = Coordinates3D(x: landmark.x, y: landmark.y, z: rawNear.z);
    expectCloseTo(snapped.x, 10.0, 1e-4, 'Snapped X');
    expectCloseTo(snapped.y, 10.0, 1e-4, 'Snapped Y');

    // Test 2: Corridor segment from (0,0) to (20,0) (East-West corridor)
    // Corridor half-width = 1.4m.
    // User is at (10.0, 3.0), which is 3.0m off the centerline (outside the 1.4m corridor wall).
    final segA = Coordinates3D(x: 0.0, y: 0.0, z: 0.0);
    final segB = Coordinates3D(x: 20.0, y: 0.0, z: 0.0);
    final rawDrift = Coordinates3D(x: 10.0, y: 3.0, z: 0.0);

    final dx = segB.x - segA.x;
    final dy = segB.y - segA.y;
    final segLengthSq = dx * dx + dy * dy;
    final t = (((rawDrift.x - segA.x) * dx + (rawDrift.y - segA.y) * dy) / segLengthSq).clamp(0.0, 1.0);
    final projX = segA.x + t * dx;
    final projY = segA.y + t * dy;
    final perpDist = math.sqrt((rawDrift.x - projX) * (rawDrift.x - projX) + (rawDrift.y - projY) * (rawDrift.y - projY));

    expectCloseTo(perpDist, 3.0, 1e-4, 'Perpendicular drift distance');
    const maxHalfWidth = 1.4;
    expect(perpDist > maxHalfWidth, 'Drift exceeds corridor width');

    final pullFactor = maxHalfWidth / perpDist;
    final clampedX = projX + (rawDrift.x - projX) * pullFactor;
    final clampedY = projY + (rawDrift.y - projY) * pullFactor;

    expectCloseTo(clampedX, 10.0, 1e-4, 'Clamped X stays on segment center');
    expectCloseTo(clampedY, 1.4, 1e-4, 'Clamped Y restricted to physical corridor boundary');
  });

  print('\n================================================================');
  print(' TEST SUMMARY: $passedCount PASSED, $failedCount FAILED');
  print('================================================================');

  if (failedCount > 0) {
    throw Exception('Some tests failed.');
  }
}
