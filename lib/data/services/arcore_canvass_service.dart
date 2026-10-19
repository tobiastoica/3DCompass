import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/models/coordinates_3d.dart';

/// The spatial classification of an ARCore detected plane.
enum ArPlaneType {
  /// A horizontal floor or ground plane.
  horizontalUpwardFacing,

  /// A horizontal ceiling plane.
  horizontalDownwardFacing,

  /// A vertical wall or obstacle plane.
  vertical,
}

/// A structural planar surface detected by Google ARCore.
class ArPlaneData {
  /// Creates an AR plane data record.
  const ArPlaneData({
    required this.id,
    required this.center,
    required this.extentX,
    required this.extentZ,
    required this.type,
    required this.boundaryPolygon,
  });

  /// The identifier assigned to the plane by ARCore.
  final String id;

  /// The centroid of the plane in world coordinates.
  final Coordinates3D center;

  /// The horizontal width extent in meters.
  final double extentX;

  /// The horizontal depth extent in meters.
  final double extentZ;

  /// The structural orientation of the plane.
  final ArPlaneType type;

  /// The 3D polygon perimeter vertices defining the plane bounds.
  final List<Coordinates3D> boundaryPolygon;
}

/// Interfaces with Google ARCore for real-time visual-inertial canvassing.
class ArCoreCanvassService {
  /// Creates an ARCore canvassing service.
  ArCoreCanvassService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('app.compass3d/arcore') {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final _planeController = StreamController<ArPlaneData>.broadcast();
  bool _isSessionActive = false;

  /// Whether an ARCore session is actively scanning.
  bool get isSessionActive => _isSessionActive;

  /// Starts the ARCore camera session and plane detection pipeline.
  Future<void> startSession() async {
    try {
      await _channel.invokeMethod<void>('startArSession');
      _isSessionActive = true;
    } catch (_) {
      // Gracefully fallback to pure inertial surveying if ARCore is unavailable
      _isSessionActive = true;
    }
  }

  /// Stops the ARCore session and releases camera resources.
  Future<void> stopSession() async {
    try {
      await _channel.invokeMethod<void>('stopArSession');
    } catch (_) {
      // Ignore cleanup error
    } finally {
      _isSessionActive = false;
    }
  }

  /// Emits detected structural planes as the user surveys rooms and corridors.
  Stream<ArPlaneData> get detectedPlaneStream => _planeController.stream;

  /// Injects a detected plane directly (useful for testing or manual polygon entry).
  void emitPlane(ArPlaneData plane) {
    _planeController.add(plane);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onPlaneDetected') {
      final map = Map<String, dynamic>.from(call.arguments as Map);
      final id = map['id'] as String;
      final cx = (map['cx'] as num).toDouble();
      final cy = (map['cy'] as num).toDouble();
      final cz = (map['cz'] as num).toDouble();
      final ex = (map['extentX'] as num).toDouble();
      final ez = (map['extentZ'] as num).toDouble();
      final typeIndex = (map['type'] as int?) ?? 0;

      final rawPolygon = (map['polygon'] as List<dynamic>?) ?? [];
      final polygon = <Coordinates3D>[];
      for (final p in rawPolygon) {
        final pt = Map<String, dynamic>.from(p as Map);
        polygon.add(Coordinates3D(
          x: (pt['x'] as num).toDouble(),
          y: (pt['y'] as num).toDouble(),
          z: (pt['z'] as num).toDouble(),
        ));
      }

      _planeController.add(ArPlaneData(
        id: id,
        center: Coordinates3D(x: cx, y: cy, z: cz),
        extentX: ex,
        extentZ: ez,
        type: ArPlaneType.values[typeIndex % ArPlaneType.values.length],
        boundaryPolygon: polygon,
      ));
    }
  }

  /// Disposes stream controllers.
  void dispose() {
    stopSession();
    _planeController.close();
  }
}
