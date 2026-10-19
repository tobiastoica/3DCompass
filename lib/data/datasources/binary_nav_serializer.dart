import 'dart:typed_data';
import '../../domain/models/coordinates_3d.dart';
import '../../domain/models/floor_level.dart';
import '../../domain/models/nav_edge.dart';
import '../../domain/models/nav_graph_3d.dart';
import '../../domain/models/nav_node.dart';

/// Serializes and deserializes 3D building navigation graphs into high-speed binary `.3dnav` buffers.
class BinaryNavSerializer {
  /// The 4-byte magic number identifying the format ("3DNV" in ASCII little-endian: 0x564E4433).
  static const int magicHeader = 0x564E4433;

  /// Serializes [graph] and [floors] into a contiguous IEEE-754 binary byte buffer.
  Uint8List serialize({
    required NavGraph3D graph,
    required List<FloorLevel> floors,
  }) {
    final nodeList = graph.nodes.values.toList();
    final edgeList = graph.allEdges;

    const headerSize = 32;
    final floorTableSize = floors.length * 16;
    final nodesBufferSize = nodeList.length * 20;
    final edgesBufferSize = edgeList.length * 16;
    final totalSize = headerSize + floorTableSize + nodesBufferSize + edgesBufferSize;

    final bytes = Uint8List(totalSize);
    final byteData = ByteData.sublistView(bytes);

    var offset = 0;

    // 1. Header (32 bytes)
    byteData.setUint32(offset, magicHeader, Endian.little);
    offset += 4;
    byteData.setUint16(offset, 1, Endian.little); // Version 1
    offset += 2;
    byteData.setUint16(offset, floors.length, Endian.little);
    offset += 2;
    byteData.setUint32(offset, nodeList.length, Endian.little);
    offset += 4;
    byteData.setUint32(offset, edgeList.length, Endian.little);
    offset += 4;
    offset += 16; // Reserved padding

    // 2. Floor Table (floors.length * 16 bytes)
    for (final floor in floors) {
      byteData.setInt16(offset, floor.floorIndex, Endian.little);
      offset += 2;
      byteData.setFloat32(offset, floor.baseElevationMeters, Endian.little);
      offset += 4;
      byteData.setFloat32(offset, floor.floorHeightMeters, Endian.little);
      offset += 4;
      offset += 6; // Reserved padding per floor
    }

    // 3. Nodes Buffer (nodeList.length * 20 bytes)
    final nodeIdToIndex = <String, int>{};
    for (var i = 0; i < nodeList.length; i++) {
      final node = nodeList[i];
      nodeIdToIndex[node.id] = i;

      byteData.setUint32(offset, node.id.hashCode & 0xFFFFFFFF, Endian.little);
      offset += 4;
      byteData.setFloat32(offset, node.position.x, Endian.little);
      offset += 4;
      byteData.setFloat32(offset, node.position.y, Endian.little);
      offset += 4;
      byteData.setFloat32(offset, node.position.z, Endian.little);
      offset += 4;
      byteData.setInt16(offset, node.floorIndex, Endian.little);
      offset += 2;
      byteData.setUint16(offset, node.type.index, Endian.little);
      offset += 2;
    }

    // 4. Edges Buffer (edgeList.length * 16 bytes)
    for (final edge in edgeList) {
      final sourceIdx = nodeIdToIndex[edge.sourceNodeId] ?? 0;
      final targetIdx = nodeIdToIndex[edge.targetNodeId] ?? 0;

      byteData.setUint32(offset, sourceIdx, Endian.little);
      offset += 4;
      byteData.setUint32(offset, targetIdx, Endian.little);
      offset += 4;
      byteData.setFloat32(offset, edge.distanceMeters, Endian.little);
      offset += 4;
      byteData.setUint16(offset, edge.transitionType.index, Endian.little);
      offset += 2;
      byteData.setUint16(offset, edge.isWheelchairAccessible ? 1 : 0, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  /// Deserializes a `.3dnav` [bytes] buffer into a [NavGraph3D] and list of [FloorLevel]s.
  ///
  /// Throws a [FormatException] if the magic header does not match [magicHeader].
  ({NavGraph3D graph, List<FloorLevel> floors}) deserialize(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    var offset = 0;

    final magic = byteData.getUint32(offset, Endian.little);
    offset += 4;
    if (magic != magicHeader) {
      throw const FormatException('Invalid .3dnav file magic header.');
    }

    final _ = byteData.getUint16(offset, Endian.little); // version
    offset += 2;
    final floorCount = byteData.getUint16(offset, Endian.little);
    offset += 2;
    final nodeCount = byteData.getUint32(offset, Endian.little);
    offset += 4;
    final edgeCount = byteData.getUint32(offset, Endian.little);
    offset += 4;
    offset += 16; // Skip reserved header padding

    // Read Floor Table
    final floors = <FloorLevel>[];
    for (var i = 0; i < floorCount; i++) {
      final floorIndex = byteData.getInt16(offset, Endian.little);
      offset += 2;
      final baseElevation = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final floorHeight = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      offset += 6; // Skip padding

      floors.add(FloorLevel(
        floorIndex: floorIndex,
        name: 'Floor $floorIndex',
        baseElevationMeters: baseElevation,
        floorHeightMeters: floorHeight,
      ));
    }

    // Read Nodes Buffer
    final nodes = <String, NavNode>{};
    final indexToId = <int, String>{};

    for (var i = 0; i < nodeCount; i++) {
      final idHash = byteData.getUint32(offset, Endian.little);
      offset += 4;
      final x = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final y = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final z = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final floorIndex = byteData.getInt16(offset, Endian.little);
      offset += 2;
      final typeIndex = byteData.getUint16(offset, Endian.little);
      offset += 2;

      final nodeId = 'node_$idHash';
      indexToId[i] = nodeId;
      nodes[nodeId] = NavNode(
        id: nodeId,
        name: 'Node $i',
        position: Coordinates3D(x: x, y: y, z: z),
        floorIndex: floorIndex,
        type: NodeType.values[typeIndex % NodeType.values.length],
      );
    }

    // Read Edges Buffer
    final edges = <NavEdge>[];
    for (var i = 0; i < edgeCount; i++) {
      final sourceIdx = byteData.getUint32(offset, Endian.little);
      offset += 4;
      final targetIdx = byteData.getUint32(offset, Endian.little);
      offset += 4;
      final distance = byteData.getFloat32(offset, Endian.little);
      offset += 4;
      final transitionIdx = byteData.getUint16(offset, Endian.little);
      offset += 2;
      final isAccessible = byteData.getUint16(offset, Endian.little) == 1;
      offset += 2;

      final sourceId = indexToId[sourceIdx];
      final targetId = indexToId[targetIdx];
      if (sourceId != null && targetId != null) {
        edges.add(NavEdge(
          sourceNodeId: sourceId,
          targetNodeId: targetId,
          distanceMeters: distance,
          transitionType: VerticalTransition.values[transitionIdx % VerticalTransition.values.length],
          isWheelchairAccessible: isAccessible,
        ));
      }
    }

    return (graph: NavGraph3D(nodes: nodes, edges: edges), floors: floors);
  }
}
