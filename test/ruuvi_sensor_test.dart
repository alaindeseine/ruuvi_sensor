import 'package:flutter_test/flutter_test.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

void main() {
  group('RuuviHistoryMeasurement', () {
    final measurement = RuuviHistoryMeasurement(
      timestamp: DateTime.utc(2026, 1, 15, 8),
      temperature: 20.0,
      humidity: 45.5,
      pressure: 1013.25,
    );

    test('converts temperature to Fahrenheit', () {
      expect(measurement.getTemperatureFahrenheit(), closeTo(68.0, 1e-9));
    });

    test('converts pressure to mmHg and inHg', () {
      expect(measurement.getPressureMmHg(), closeTo(760.0, 0.01));
      expect(measurement.getPressureInHg(), closeTo(29.92, 0.01));
    });

    test('temperature-only measurement is not complete', () {
      final tempOnly = RuuviHistoryMeasurement(
        timestamp: DateTime.utc(2026, 1, 15, 8),
        temperature: -0.01,
      );
      expect(tempOnly.isComplete(), isFalse);
      expect(tempOnly.getAvailableSensors(), ['temperature']);
      expect(tempOnly.getPressureMmHg(), isNull);
    });

    test('round-trips through toMap/fromMap', () {
      expect(RuuviHistoryMeasurement.fromMap(measurement.toMap()), measurement);
    });
  });

  group('RuuviHistoryCollection', () {
    final collection = RuuviHistoryCollection(
      deviceId: 'AA:BB:CC:DD:EE:FF',
      measurements: [
        RuuviHistoryMeasurement(
          timestamp: DateTime.utc(2026, 1, 15, 8),
          temperature: 10.0,
        ),
        RuuviHistoryMeasurement(
          timestamp: DateTime.utc(2026, 1, 15, 9),
          temperature: 20.0,
          humidity: 50.0,
          pressure: 1000.0,
        ),
      ],
    );

    test('exposes first, last and time range', () {
      expect(collection.length, 2);
      expect(collection.first!.temperature, 10.0);
      expect(collection.last!.temperature, 20.0);
      expect(collection.timeRange, const Duration(hours: 1));
    });

    test('averages only the values that are present', () {
      final averages = collection.getAverages();
      expect(averages['temperature'], 15.0);
      expect(averages['humidity'], 50.0);
      expect(averages['pressure'], 1000.0);
    });

    test('getCompleteOnly keeps measurements with all sensors', () {
      expect(collection.getCompleteOnly().length, 1);
    });

    test('filterByDateRange includes both bounds', () {
      final filtered = collection.filterByDateRange(
        DateTime.utc(2026, 1, 15, 8),
        DateTime.utc(2026, 1, 15, 9),
      );
      expect(filtered.length, 2);
    });

    test('is complete by default and propagates the flag', () {
      expect(collection.isComplete, isTrue);
      final partial = RuuviHistoryCollection(
        deviceId: collection.deviceId,
        measurements: collection.measurements,
        isComplete: false,
      );
      expect(partial.getCompleteOnly().isComplete, isFalse);
      expect(
        partial.filterByDateRange(DateTime(2000), DateTime(2100)).isComplete,
        isFalse,
      );
    });
  });

  group('RuuviBleScanResult', () {
    test('exposes pressure in hPa alongside Pa', () {
      final result = RuuviBleScanResult(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: '',
        rssi: -60,
        pressure: 101325,
        lastSeen: DateTime(2026),
      );
      expect(result.pressureHPa, closeTo(1013.25, 1e-9));
      expect(result.displayName, 'Ruuvi EEFF');
      expect(result.hasValidData, isFalse);
    });
  });

  group('RuuviTagInformation', () {
    test('falls back to the MAC address and builds a display name', () {
      const info = RuuviTagInformation(
        identifier: 'AA:BB:CC:DD:EE:FF',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );
      expect(info.hasSerialNumber(), isFalse);
      expect(info.getDisplayName(), 'Ruuvi EEFF');
    });
  });
}
