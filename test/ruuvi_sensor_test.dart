import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

void main() {
  group('RuuviDataDecoder', () {
    test('decodes valid Ruuvi format 5 data correctly', () {
      // Test vector from Ruuvi documentation
      final testData = Uint8List.fromList([
        0x05, 0x12, 0xFC, 0x53, 0x94, 0xC3, 0x7C, 0x00, 0x04, 0xFF, 0xFC, 0x04, 0x0C, 0xAC, 0x36, 0x42, 0x00, 0xCD, 0xCB, 0xB8, 0x33, 0x4C, 0x88, 0x4F
      ]);

      final manufacturerData = <int, Uint8List>{
        0x0499: testData,
      };

      final result = RuuviDataDecoder.decodeManufacturerData(
        manufacturerData,
        'test-device-id',
        -50,
      );

      expect(result, isNotNull);
      expect(result!.temperature, closeTo(24.3, 0.1));
      expect(result.humidity, closeTo(53.49, 0.1));
      expect(result.pressure, closeTo(100044, 1));
      expect(result.deviceId, equals('test-device-id'));
      expect(result.rssi, equals(-50));
      expect(result.serialNumber, equals('CB:B8:33:4C:88:4F'));
    });

    test('returns null for non-Ruuvi manufacturer data', () {
      final manufacturerData = <int, Uint8List>{
        0x1234: Uint8List.fromList([0x01, 0x02, 0x03]),
      };

      final result = RuuviDataDecoder.decodeManufacturerData(
        manufacturerData,
        'test-device-id',
        -50,
      );

      expect(result, isNull);
    });

    test('throws exception for unsupported data format', () {
      final testData = Uint8List.fromList([
        0x03, 0x12, 0xFC, 0x53, // Format 3 instead of 5
      ]);

      final manufacturerData = <int, Uint8List>{
        0x0499: testData,
      };

      expect(
        () => RuuviDataDecoder.decodeManufacturerData(
          manufacturerData,
          'test-device-id',
          -50,
        ),
        throwsA(isA<RuuviDataException>()),
      );
    });
  });

  group('RuuviData', () {
    test('creates data object with correct properties', () {
      final data = RuuviData(
        deviceId: 'test-device',
        serialNumber: 'CB:B8:33:4C:88:4F',
        temperature: 24.3,
        humidity: 53.49,
        pressure: 100044,
        timestamp: DateTime.now(),
        batteryVoltage: 2977,
        rssi: -50,
      );

      expect(data.deviceId, equals('test-device'));
      expect(data.serialNumber, equals('CB:B8:33:4C:88:4F'));
      expect(data.temperature, equals(24.3));
      expect(data.humidity, equals(53.49));
      expect(data.pressure, equals(100044));
      expect(data.batteryVoltage, equals(2977));
      expect(data.rssi, equals(-50));
    });
  });

  group('RuuviMeasurement', () {
    test('creates measurement collection correctly', () {
      final now = DateTime.now();
      final data1 = RuuviData(
        deviceId: 'test-device',
        temperature: 20.0,
        humidity: 50.0,
        pressure: 100000,
        timestamp: now.subtract(const Duration(hours: 1)),
      );
      final data2 = RuuviData(
        deviceId: 'test-device',
        temperature: 22.0,
        humidity: 52.0,
        pressure: 100100,
        timestamp: now,
      );

      final measurement = RuuviMeasurement(
        measurements: [data1, data2],
        startTime: data1.timestamp,
        endTime: data2.timestamp,
        totalCount: 2,
      );

      expect(measurement.measurements.length, equals(2));
      expect(measurement.totalCount, equals(2));
      expect(measurement.startTime, equals(data1.timestamp));
      expect(measurement.endTime, equals(data2.timestamp));
    });
  });
}
