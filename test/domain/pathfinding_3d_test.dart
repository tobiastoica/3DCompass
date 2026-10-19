import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_graph_3d.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:compass_3d/domain/use_cases/compute_shortest_3d_path_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComputeShortest3DPathUseCase (3D A* Search)', () {
    const useCase = ComputeShortest3DPathUseCase();

    late NavGraph3D multiFloorGraph;

    setUp(() {
      // Create a 2-floor building graph with both stairs and an elevator
      final nodes = <String, NavNode>{
        // Floor 0
        'f0_room_a': const NavNode(id: 'f0_room_a', name: 'Room A', position: Coordinates3D(x: 0, y: 0, z: 0), floorIndex: 0, type: NodeType.room),
        'f0_hall': const NavNode(id: 'f0_hall', name: 'F0 Hall', position: Coordinates3D(x: 10, y: 0, z: 0), floorIndex: 0, type: NodeType.hallway),
        'f0_stairs': const NavNode(id: 'f0_stairs', name: 'F0 Stairs', position: Coordinates3D(x: 20, y: 0, z: 0), floorIndex: 0, type: NodeType.stairs),
        'f0_elevator': const NavNode(id: 'f0_elevator', name: 'F0 Elevator', position: Coordinates3D(x: 10, y: 15, z: 0), floorIndex: 0, type: NodeType.elevator),

        // Floor 1
        'f1_stairs': const NavNode(id: 'f1_stairs', name: 'F1 Stairs', position: Coordinates3D(x: 20, y: 0, z: 3.6), floorIndex: 1, type: NodeType.stairs),
        'f1_elevator': const NavNode(id: 'f1_elevator', name: 'F1 Elevator', position: Coordinates3D(x: 10, y: 15, z: 3.6), floorIndex: 1, type: NodeType.elevator),
        'f1_hall': const NavNode(id: 'f1_hall', name: 'F1 Hall', position: Coordinates3D(x: 10, y: 0, z: 3.6), floorIndex: 1, type: NodeType.hallway),
        'f1_room_b': const NavNode(id: 'f1_room_b', name: 'Room B', position: Coordinates3D(x: 0, y: 0, z: 3.6), floorIndex: 1, type: NodeType.room),
      };

      final edges = <NavEdge>[
        // F0 connections
        const NavEdge(sourceNodeId: 'f0_room_a', targetNodeId: 'f0_hall', distanceMeters: 10.0),
        const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_stairs', distanceMeters: 10.0),
        const NavEdge(sourceNodeId: 'f0_hall', targetNodeId: 'f0_elevator', distanceMeters: 15.0),

        // Vertical Transitions
        const NavEdge(sourceNodeId: 'f0_stairs', targetNodeId: 'f1_stairs', distanceMeters: 5.0, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
        const NavEdge(sourceNodeId: 'f0_elevator', targetNodeId: 'f1_elevator', distanceMeters: 5.0, transitionType: VerticalTransition.elevator, isWheelchairAccessible: true),

        // F1 connections
        const NavEdge(sourceNodeId: 'f1_stairs', targetNodeId: 'f1_hall', distanceMeters: 10.0),
        const NavEdge(sourceNodeId: 'f1_elevator', targetNodeId: 'f1_hall', distanceMeters: 15.0),
        const NavEdge(sourceNodeId: 'f1_hall', targetNodeId: 'f1_room_b', distanceMeters: 10.0),
      ];

      multiFloorGraph = NavGraph3D(nodes: nodes, edges: edges);
    });

    test('finds optimal path from Floor 0 to Floor 1 via stairs when default', () {
      final path = useCase.execute(
        graph: multiFloorGraph,
        startNodeId: 'f0_room_a',
        targetNodeId: 'f1_room_b',
      );

      expect(path.isNotEmpty, isTrue);
      expect(path.startNode?.id, equals('f0_room_a'));
      expect(path.destinationNode?.id, equals('f1_room_b'));

      final waypointIds = path.waypoints.map((w) => w.id).toList();
      expect(waypointIds, contains('f0_stairs'));
      expect(waypointIds, contains('f1_stairs'));
    });

    test('routes strictly via elevator when wheelchair accessibility is required', () {
      final path = useCase.execute(
        graph: multiFloorGraph,
        startNodeId: 'f0_room_a',
        targetNodeId: 'f1_room_b',
        requireElevatorOnly: true,
      );

      expect(path.isNotEmpty, isTrue);
      final waypointIds = path.waypoints.map((w) => w.id).toList();

      expect(waypointIds, contains('f0_elevator'));
      expect(waypointIds, contains('f1_elevator'));
      expect(waypointIds, isNot(contains('f0_stairs')));
    });

    test('returns single node path when start and destination are identical', () {
      final path = useCase.execute(
        graph: multiFloorGraph,
        startNodeId: 'f0_room_a',
        targetNodeId: 'f0_room_a',
      );

      expect(path.waypoints.length, equals(1));
      expect(path.startNode?.id, equals('f0_room_a'));
    });
  });
}
