import 'dart:math' as math;
import 'package:compass_3d/data/services/extended_kalman_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtendedKalmanFilter Sensor Fusion Tests', () {
    late ExtendedKalmanFilter ekf;

    setUp(() {
      ekf = ExtendedKalmanFilter();
    });

    test('initializes state at zero reference origin', () {
      expect(ekf.position.x, equals(0.0));
      expect(ekf.position.y, equals(0.0));
      expect(ekf.position.z, equals(0.0));
      expect(ekf.headingRadians, equals(0.0));
      expect(ekf.horizontalAccuracyMeters, lessThan(1.0));
    });

    test('predicts position displacement accurately along heading vector', () {
      // Step 1: 0.8 meters directly East (heading = 0 rad)
      ekf.predictStep(stepLengthMeters: 0.8, measuredHeadingRadians: 0.0);
      expect(ekf.position.x, closeTo(0.8, 0.01));
      expect(ekf.position.y, closeTo(0.0, 0.01));

      // Step 2: 0.8 meters directly North (heading = pi/2 rad)
      ekf.predictStep(stepLengthMeters: 0.8, measuredHeadingRadians: math.pi / 2.0);
      expect(ekf.position.x, greaterThan(0.7));
      expect(ekf.position.y, greaterThan(0.5));
    });

    test('updates vertical elevation and contracts variance with barometer measurements', () {
      ekf.updateBarometerAltitude(3.6);
      expect(ekf.position.z, greaterThan(3.0));
      expect(ekf.position.z, lessThan(3.7));

      // Successive readings converge filter
      ekf.updateBarometerAltitude(3.6);
      ekf.updateBarometerAltitude(3.6);
      expect(ekf.position.z, closeTo(3.6, 0.05));
    });

    test('fuses faint GNSS fixes within gate and rejects multipath outliers', () {
      // Drifting position
      ekf.predictStep(stepLengthMeters: 1.0, measuredHeadingRadians: 0.0);

      // Faint GNSS measurement (accuracy = 15m) gently pulls position
      ekf.updateGpsFix(localX: 0.9, localY: 0.1, accuracyMeters: 15.0);
      expect(ekf.position.x, closeTo(0.95, 0.1));

      // Multipath outlier (accuracy = 60m > 35m gate) must be ignored
      final preX = ekf.position.x;
      ekf.updateGpsFix(localX: 99.0, localY: 99.0, accuracyMeters: 60.0);
      expect(ekf.position.x, equals(preX));
    });
  });
}
