import 'dart:typed_data';
import 'package:compass_3d/data/datasources/binary_nav_serializer.dart';
import 'package:compass_3d/domain/models/coordinates_3d.dart';
import 'package:compass_3d/domain/models/floor_level.dart';
import 'package:compass_3d/domain/models/nav_edge.dart';
import 'package:compass_3d/domain/models/nav_graph_3d.dart';
import 'package:compass_3d/domain/models/nav_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BinaryNavSerializer Tests', () {
    late BinaryNavSerializer serializer;

    setUp(() {
      serializer = BinaryNavSerializer();
    });

    test('serializes and deserializes multi-floor building graph accurately', () {
      final floors = [
        const FloorLevel(floorIndex: 0, name: 'Ground', baseElevationMeters: 0.0, floorHeightMeters: 3.6),
        const FloorLevel(floorIndex: 1, name: 'First', baseElevationMeters: 3.6, floorHeightMeters: 3.6),
      ];

      final nodes = <String, NavNode>{
        'n1': const NavNode(id: 'n1', name: 'Node 1', position: Coordinates3D(x: 12.345, y: -67.89, z: 0.0), floorIndex: 0, type: NodeType.doorway),
        'n2': const NavNode(id: 'n2', name: 'Node 2', position: Coordinates3D(x: 25.0, y: 10.0, z: 3.6), floorIndex: 1, type: NodeType.room),
      };

      final edges = <NavEdge>[
        const NavEdge(sourceNodeId: 'n1', targetNodeId: 'n2', distanceMeters: 22.5, transitionType: VerticalTransition.stairs, isWheelchairAccessible: false),
      ];

      final graph = NavGraph3D(nodes: nodes, edges: edges);

      // Serialize to binary
      final bytes = serializer.serialize(graph: graph, floors: floors);
      expect(bytes, isNotEmpty);

      // Verify magic header "3DNV"
      expect(bytes.sublist(0, 4), equals([0x33, 0x44, 0x4E, 0x56]));

      // Deserialize
      final result = serializer.deserialize(bytes);
      expect(result.floors.length, equals(2));
      expect(result.floors[0].floorIndex, equals(0));
      expect(result.floors[1].baseElevationMeters, closeTo(3.6, 0.001));

      expect(result.graph.nodes.length, equals(2));
      final decodedNode1 = result.graph.nodes.values.firstWhere((n) => (n.position.x - 12.345).abs() < 0.001);
      expect(decodedNode1.position.y, closeTo(-67.89, 0.001));
      expect(decodedNode1.floorIndex, equals(0));

      expect(result.graph.allEdges.length, equals(1));
      expect(result.graph.allEdges[0].distanceMeters, closeTo(22.5, 0.001));
      expect(result.graph.allEdges[0].transitionType, equals(VerticalTransition.stairs));
      expect(result.graph.allEdges[0].isWheelchairAccessible, isFalse);
    });

    test('rejects corrupted or invalid magic headers', () {
      final invalidBytes = [0x00, 0x00, 0x00, 0x00, 0x01, 0x02];
      expect(
        () => serializer.deserialize(Uint8List.fromList(invalidBytes)),
        throwsFormatException,
      );
    });
  });
}
