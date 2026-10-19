import 'package:compass_3d/data/services/barometric_altimeter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarometricAltimeterService Tests', () {
    late BarometricAltimeterService altimeter;

    setUp(() {
      altimeter = BarometricAltimeterService();
    });

    test('calculates 0m relative altitude when pressure equals latched entrance baseline', () {
      altimeter.latchBaseline(1013.25);
      expect(altimeter.isCalibrated, isTrue);
      expect(altimeter.entrancePressureHpa, equals(1013.25));

      final relativeAltitude = altimeter.calculateRelativeAltitude(1013.25);
      expect(relativeAltitude, closeTo(0.0, 0.01));
    });

    test('calculates accurate positive elevation change as pressure drops', () {
      altimeter.latchBaseline(1013.25);

      // Dropping pressure by ~1.2 hPa represents approximately ~10 meters elevation gain
      final altAt1012 = altimeter.calculateRelativeAltitude(1012.0);
      expect(altAt1012, greaterThan(9.0));
      expect(altAt1012, lessThan(12.0));

      // Dropping pressure to 1000 hPa represents ~110.8 meters
      final altAt1000 = altimeter.calculateRelativeAltitude(1000.0);
      expect(altAt1000, closeTo(110.8, 2.0));
    });

    test('classifies floor indices correctly with interval steps', () {
      expect(altimeter.estimateFloorIndex(0.0, floorHeightMeters: 3.6), equals(0));
      expect(altimeter.estimateFloorIndex(3.5, floorHeightMeters: 3.6), equals(1));
      expect(altimeter.estimateFloorIndex(7.3, floorHeightMeters: 3.6), equals(2));
      expect(altimeter.estimateFloorIndex(-3.5, floorHeightMeters: 3.6), equals(-1));
    });
  });
}
