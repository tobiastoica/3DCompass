import 'coordinates_3d.dart';
import 'orientation_3d.dart';

/// The sensor-fused state estimate of a user's location inside a building.
class PositionEstimate {
  /// Creates a position estimate.
  const PositionEstimate({
    required this.position,
    required this.orientation,
    required this.floorIndex,
    required this.horizontalAccuracyMeters,
    required this.timestamp,
    this.isNearEntrance = false,
  });

  /// The estimated 3D spatial coordinate in the building frame.
  final Coordinates3D position;

  /// The current orientation and attitude of the phone.
  final Orientation3D orientation;

  /// The active floor index derived from barometric altimetry.
  final int floorIndex;

  /// The estimated horizontal accuracy radius in meters (one standard deviation).
  final double horizontalAccuracyMeters;

  /// The timestamp when this estimate was computed.
  final DateTime timestamp;

  /// Whether the user is estimated to be within immediate proximity of an entrance.
  final bool isNearEntrance;

  /// A default initial estimate at the entrance origin.
  static PositionEstimate initialAtOrigin() {
    return PositionEstimate(
      position: Coordinates3D.zero,
      orientation: Orientation3D.neutral,
      floorIndex: 0,
      horizontalAccuracyMeters: 1.0,
      timestamp: DateTime.now(),
      isNearEntrance: true,
    );
  }
}
