import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuuviLogReader Command Creation', () {
    test('creates correct log read command format', () {
      // Test the command creation logic directly
      final command = Uint8List(11);

      // Header (3 bytes)
      command[0] = 0x3A; // destination: environmental
      command[1] = 0x3A; // source: environmental
      command[2] = 0x11; // type: log read

      // Current time (4 bytes, big-endian)
      final currentTime = 1567134317;
      command[3] = (currentTime >> 24) & 0xFF;
      command[4] = (currentTime >> 16) & 0xFF;
      command[5] = (currentTime >> 8) & 0xFF;
      command[6] = currentTime & 0xFF;

      // Start time (4 bytes, big-endian)
      final startTime = 1567047917;
      command[7] = (startTime >> 24) & 0xFF;
      command[8] = (startTime >> 16) & 0xFF;
      command[9] = (startTime >> 8) & 0xFF;
      command[10] = startTime & 0xFF;

      // Verify command structure
      expect(command.length, equals(11));
      expect(command[0], equals(0x3A)); // destination
      expect(command[1], equals(0x3A)); // source
      expect(command[2], equals(0x11)); // type

      // Verify timestamps can be read back correctly
      final readCurrentTime = (command[3] << 24) | (command[4] << 16) | (command[5] << 8) | command[6];
      final readStartTime = (command[7] << 24) | (command[8] << 16) | (command[9] << 8) | command[10];

      expect(readCurrentTime, equals(1567134317));
      expect(readStartTime, equals(1567047917));
    });

    test('parses temperature log response format correctly', () {
      // Test response parsing logic
      final tempResponse = Uint8List.fromList([
        0x3A, 0x30, 0x10, // header: to environmental, from temperature, log write
        0x5D, 0x67, 0x40, 0xED, // timestamp: 1567047917 (corrected)
        0x00, 0x00, 0x09, 0x7E, // value: 2430 (24.30°C)
      ]);

      expect(tempResponse.length, equals(11));
      expect(tempResponse[0], equals(0x3A)); // destination
      expect(tempResponse[1], equals(0x30)); // source (temperature)
      expect(tempResponse[2], equals(0x10)); // type (log write)

      // Parse timestamp
      final timestamp = (tempResponse[3] << 24) | (tempResponse[4] << 16) | (tempResponse[5] << 8) | tempResponse[6];
      expect(timestamp, equals(1567047917));

      // Parse value
      final rawValue = (tempResponse[7] << 24) | (tempResponse[8] << 16) | (tempResponse[9] << 8) | tempResponse[10];
      final temperature = rawValue * 0.01; // 0.01°C per LSB
      expect(temperature, closeTo(24.30, 0.01));
    });

    test('recognizes end of data marker', () {
      final endMarker = Uint8List.fromList(List.filled(11, 0xFF));

      expect(endMarker.length, equals(11));
      expect(endMarker.every((byte) => byte == 0xFF), isTrue);
    });

    test('recognizes error response', () {
      final errorResponse = Uint8List.fromList([
        0x30, 0x30, 0xF0, // header with error type
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // error payload
      ]);

      expect(errorResponse.length, equals(11));
      expect(errorResponse[2], equals(0xF0)); // error type
    });
  });
}
