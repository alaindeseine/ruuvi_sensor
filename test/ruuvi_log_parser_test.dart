import 'package:flutter_test/flutter_test.dart';
import 'package:ruuvi_sensor/src/ruuvi_log_parser.dart';

List<int> packet(int source, int op, int timestamp, int value) => [
  0x3A,
  source,
  op,
  (timestamp >> 24) & 0xFF,
  (timestamp >> 16) & 0xFF,
  (timestamp >> 8) & 0xFF,
  timestamp & 0xFF,
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

void main() {
  const ts = 1767225600; // 2026-01-01T00:00:00Z

  test('decodes temperature in hundredths of °C', () {
    // Firmware endpoint test: 22.554 °C is encoded as 0x08CF (2255).
    final p = parseRuuviLogPacket(packet(0x30, 0x10, ts, 0x08CF));
    expect(p, isA<RuuviLogValue>());
    p as RuuviLogValue;
    expect(p.timestamp, ts);
    expect(p.sensorType, 'temperature');
    expect(p.value, closeTo(22.55, 1e-9));
  });

  test('decodes negative temperature', () {
    // Firmware endpoint test: -22.554 °C is encoded as 0xFFFFF731.
    final p =
        parseRuuviLogPacket(packet(0x30, 0x10, ts, 0xFFFFF731))
            as RuuviLogValue;
    expect(p.value, closeTo(-22.55, 1e-9));
  });

  test('-0.01 °C is a value, not the end-of-log marker', () {
    final p = parseRuuviLogPacket(packet(0x30, 0x10, ts, 0xFFFFFFFF));
    expect(p, isA<RuuviLogValue>());
    expect((p as RuuviLogValue).value, closeTo(-0.01, 1e-9));
  });

  test('decodes humidity in hundredths of %', () {
    final p =
        parseRuuviLogPacket(packet(0x31, 0x10, ts, 0x08CF)) as RuuviLogValue;
    expect(p.sensorType, 'humidity');
    expect(p.value, closeTo(22.55, 1e-9));
  });

  test('decodes pressure from Pa to hPa', () {
    // Firmware endpoint test: 100101.546 Pa is encoded as 0x018706.
    final p =
        parseRuuviLogPacket(packet(0x32, 0x10, ts, 0x018706)) as RuuviLogValue;
    expect(p.sensorType, 'pressure');
    expect(p.value, closeTo(1001.02, 1e-9));
  });

  test('recognises the end-of-log marker (payload all 0xFF)', () {
    expect(
      parseRuuviLogPacket(packet(0x3A, 0x10, 0xFFFFFFFF, 0xFFFFFFFF)),
      isA<RuuviLogEnd>(),
    );
  });

  test('recognises the firmware timeout message', () {
    expect(
      parseRuuviLogPacket(packet(0x3A, 0xE0, 0xFFFFFFFF, 0xFFFFFFFF)),
      isA<RuuviLogAborted>(),
    );
  });

  test('ignores unknown endpoints, operations and lengths', () {
    expect(parseRuuviLogPacket(packet(0x40, 0x10, ts, 1)), isNull);
    expect(parseRuuviLogPacket(packet(0x30, 0x11, ts, 1)), isNull);
    expect(parseRuuviLogPacket([0x3A, 0x30, 0x10]), isNull);
  });
}
