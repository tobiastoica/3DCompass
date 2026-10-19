import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// A GNSS position fix with associated horizontal uncertainty.
class GpsFixEvent {
  /// Creates a GPS fix event.
  const GpsFixEvent({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  /// The latitude in degrees.
  final double latitude;

  /// The longitude in degrees.
  final double longitude;

  /// The estimated horizontal accuracy radius in meters (one standard deviation).
  final double accuracyMeters;

  /// The timestamp of the fix.
  final DateTime timestamp;

  /// Whether the fix is sufficiently reliable for bounded indoor correlation.
  bool get isUsableIndoorFix => accuracyMeters <= 35.0;
}

/// Provides filtered faint GNSS fixes to bound indoor drift near windows and atriums.
class FaintGpsService {
  /// Creates a faint GPS service.
  FaintGpsService();

  StreamSubscription<Position>? _positionSub;
  final _fixController = StreamController<GpsFixEvent>.broadcast();

  /// Emits received GNSS fixes with accuracy estimates.
  Stream<GpsFixEvent> get fixStream => _fixController.stream;

  /// Starts listening to device location updates.
  Future<void> start() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // trigger on small movements
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _fixController.add(GpsFixEvent(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracyMeters: pos.accuracy,
          timestamp: pos.timestamp,
        ));
      },
      onError: (_) {
        // GPS lost or unavailable indoors - expected behavior
      },
    );
  }

  /// Stops listening to GPS updates to conserve battery.
  void stop() {
    _positionSub?.cancel();
  }

  /// Disposes stream resources.
  void dispose() {
    stop();
    _fixController.close();
  }
}
