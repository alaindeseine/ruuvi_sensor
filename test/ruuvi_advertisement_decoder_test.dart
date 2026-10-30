import 'package:flutter_test/flutter_test.dart';
import 'package:ruuvi_sensor/src/ruuvi_advertisement_decoder.dart';

/// Test vectors are those of the official Ruuvi Station Android app
/// (DataFormat3DecodeTests.kt / DataFormat5DecodeTests.kt).
List<int> hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

void main() {
  group('RAWv1 (format 3)', () {
    test('decodes valid data', () {
      final d = decodeRuuviAdvertisement(hex('03291A1ECE1EFC18F94202CA0B53'))!;
      expect(d.dataFormat, 3);
      expect(d.temperature, closeTo(26.3, 1e-9));
      expect(d.humidity, 20.5);
      expect(d.pressure, 102766.0);
      expect(d.accelerationX, -1.0);
      expect(d.accelerationY, -1.726);
      expect(d.accelerationZ, 0.714);
      expect(d.batteryVoltage, 2899);
    });

    test('decodes maximum values', () {
      final d = decodeRuuviAdvertisement(hex('03FF7F63FFFF7FFF7FFF7FFFFFFF'))!;
      expect(d.temperature, closeTo(127.99, 1e-9));
      expect(d.humidity, 127.5);
      expect(d.pressure, 115535.0);
      expect(d.batteryVoltage, 65535);
    });

    test('decodes minimum values (negative temperature)', () {
      final d = decodeRuuviAdvertisement(hex('0300FF6300008001800180010000'))!;
      expect(d.temperature, closeTo(-127.99, 1e-9));
      expect(d.humidity, 0.0);
      expect(d.pressure, 50000.0);
      expect(d.accelerationX, -32.767);
      expect(d.batteryVoltage, 0);
    });

    test('rejects a truncated payload', () {
      expect(decodeRuuviAdvertisement(hex('03291A1ECE1E')), isNull);
    });
  });

  group('RAWv2 (format 5)', () {
    test('decodes valid data', () {
      final d = decodeRuuviAdvertisement(
        hex('0512FC5394C37C0004FFFC040CAC364200CDCBB8334C884F'),
      )!;
      expect(d.dataFormat, 5);
      expect(d.temperature, closeTo(24.3, 1e-9));
      expect(d.humidity, closeTo(53.49, 1e-9));
      expect(d.pressure, 100044.0);
      expect(d.accelerationX, 0.004);
      expect(d.accelerationY, -0.004);
      expect(d.accelerationZ, 1.036);
      expect(d.txPower, 4);
      expect(d.batteryVoltage, 2977);
      expect(d.movementCounter, 66);
      expect(d.measurementSequence, 205);
      expect(d.macAddress, 'CB:B8:33:4C:88:4F');
    });

    test('decodes maximum values', () {
      final d = decodeRuuviAdvertisement(
        hex('057FFFFFFEFFFE7FFF7FFF7FFFFFDEFEFFFECBB8334C884F'),
      )!;
      expect(d.temperature, closeTo(163.835, 1e-9));
      expect(d.humidity, closeTo(163.835, 1e-9));
      expect(d.pressure, 115534.0);
      expect(d.accelerationZ, 32.767);
      expect(d.txPower, 20);
      expect(d.batteryVoltage, 3646);
      expect(d.movementCounter, 254);
      expect(d.measurementSequence, 65534);
    });

    test('decodes minimum values', () {
      final d = decodeRuuviAdvertisement(
        hex('058001000000008001800180010000000000CBB8334C884F'),
      )!;
      expect(d.temperature, closeTo(-163.835, 1e-9));
      expect(d.humidity, 0.0);
      expect(d.pressure, 50000.0);
      expect(d.accelerationX, -32.767);
      expect(d.batteryVoltage, 1600);
      expect(d.txPower, -40);
    });

    test('maps every "not available" sentinel to null', () {
      final d = decodeRuuviAdvertisement(
        hex('058000FFFFFFFF800080008000FFFFFFFFFFFFFFFFFFFFFF'),
      )!;
      expect(d.dataFormat, 5);
      expect(d.temperature, isNull);
      expect(d.humidity, isNull);
      expect(d.pressure, isNull);
      expect(d.accelerationX, isNull);
      expect(d.accelerationY, isNull);
      expect(d.accelerationZ, isNull);
      expect(d.batteryVoltage, isNull);
      expect(d.txPower, isNull);
      expect(d.movementCounter, isNull);
      expect(d.measurementSequence, isNull);
      expect(d.macAddress, isNull);
    });

    test('rejects a truncated payload', () {
      expect(decodeRuuviAdvertisement(hex('0512FC5394C37C')), isNull);
    });
  });

  test('unknown format keeps only the format byte', () {
    final d = decodeRuuviAdvertisement([0xC5, 0x01, 0x02])!;
    expect(d.dataFormat, 0xC5);
    expect(d.temperature, isNull);
  });

  test('empty payload is ignored', () {
    expect(decodeRuuviAdvertisement(const []), isNull);
  });
}
