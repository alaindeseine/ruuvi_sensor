import 'dart:typed_data';
import 'models/ruuvi_data.dart';

/// Parser for RuuviTag historical data in Cut-RAWv2 format (firmware 3.31.1+)
class RuuviHistoryParser {
  
  /// Parses Cut-RAWv2 format historical data
  ///
  /// Each entry is 10 bytes:
  /// - Timestamp: 4 bytes (Unix epoch seconds, little endian)
  /// - Temperature: 2 bytes (signed, factor 0.005°C, little endian)
  /// - Humidity: 2 bytes (unsigned, factor 0.0025%, little endian)
  /// - Pressure: 2 bytes (unsigned, factor 0.1 hPa, offset 500 hPa, little endian)
  ///
  /// [data] Raw bytes received from RuuviTag
  /// [deviceId] Device identifier to assign to parsed entries
  /// Returns list of [RuuviData] entries
  static List<RuuviData> parseHistoryData(Uint8List data, String deviceId) {
    final records = <RuuviData>[];
    
    print('🔍 RuuviHistoryParser: Parsing ${data.length} bytes of history data');
    
    const entrySize = 10;
    if (data.length % entrySize != 0) {
      print('⚠️ RuuviHistoryParser: Data length ${data.length} is not multiple of $entrySize');
    }
    
    for (int i = 0; i + entrySize <= data.length; i += entrySize) {
      try {
        final chunk = data.sublist(i, i + entrySize);
        final entry = _parseHistoryEntry(chunk, i ~/ entrySize, deviceId);
        if (entry != null) {
          records.add(entry);
        }
      } catch (e) {
        print('❌ RuuviHistoryParser: Error parsing entry at offset $i: $e');
      }
    }
    
    print('✅ RuuviHistoryParser: Successfully parsed ${records.length} history entries');
    return records;
  }
  
  /// Parses a single 10-byte history entry
  static RuuviData? _parseHistoryEntry(Uint8List chunk, int entryIndex, String deviceId) {
    if (chunk.length != 10) {
      print('❌ RuuviHistoryParser: Invalid chunk size: ${chunk.length} (expected 10)');
      return null;
    }
    
    try {
      final buffer = ByteData.sublistView(chunk);
      
      // Parse timestamp (4 bytes, little endian, Unix epoch seconds)
      final epochSeconds = buffer.getUint32(0, Endian.little);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
      
      // Parse temperature (2 bytes, signed, little endian, factor 0.005°C)
      final rawTemp = buffer.getInt16(4, Endian.little);
      final temperature = rawTemp * 0.005;
      
      // Parse humidity (2 bytes, unsigned, little endian, factor 0.0025%)
      final rawHumidity = buffer.getUint16(6, Endian.little);
      final humidity = rawHumidity * 0.0025;
      
      // Parse pressure (2 bytes, unsigned, little endian, factor 0.1 hPa, offset 500 hPa)
      final rawPressure = buffer.getUint16(8, Endian.little);
      final pressure = 500 + (rawPressure * 0.1);
      
      // Validate ranges
      if (temperature < -40 || temperature > 85) {
        print('⚠️ RuuviHistoryParser: Entry $entryIndex - Temperature out of range: ${temperature.toStringAsFixed(3)}°C');
      }
      
      if (humidity < 0 || humidity > 100) {
        print('⚠️ RuuviHistoryParser: Entry $entryIndex - Humidity out of range: ${humidity.toStringAsFixed(3)}%');
      }
      
      if (pressure < 300 || pressure > 1100) {
        print('⚠️ RuuviHistoryParser: Entry $entryIndex - Pressure out of range: ${pressure.toStringAsFixed(1)} hPa');
      }
      
      print('📊 RuuviHistoryParser: Entry $entryIndex - ${timestamp.toIso8601String()} | ${temperature.toStringAsFixed(3)}°C | ${humidity.toStringAsFixed(3)}% | ${pressure.toStringAsFixed(1)} hPa');
      
      return RuuviData(
        deviceId: deviceId,
        temperature: temperature,
        humidity: humidity,
        pressure: pressure,
        timestamp: timestamp,
        accelerationX: null, // Not available in history format
        accelerationY: null, // Not available in history format
        accelerationZ: null, // Not available in history format
        batteryVoltage: null, // Not available in history format
        txPower: null, // Not available in history format
        movementCounter: null, // Not available in history format
        sequenceNumber: null, // Not available in history format
      );
      
    } catch (e) {
      print('❌ RuuviHistoryParser: Error parsing entry $entryIndex: $e');
      print('❌ RuuviHistoryParser: Raw data: ${chunk.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      return null;
    }
  }
  
  /// Validates if data looks like Cut-RAWv2 format
  static bool isValidHistoryData(Uint8List data) {
    if (data.isEmpty || data.length % 10 != 0) {
      return false;
    }
    
    // Check if first entry has reasonable timestamp (after 2020)
    if (data.length >= 10) {
      try {
        final buffer = ByteData.sublistView(data.sublist(0, 10));
        final epochSeconds = buffer.getUint32(0, Endian.little);
        final timestamp = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
        
        // Check if timestamp is reasonable (after 2020, before 2030)
        final year2020 = DateTime(2020).millisecondsSinceEpoch ~/ 1000;
        final year2030 = DateTime(2030).millisecondsSinceEpoch ~/ 1000;
        
        return epochSeconds >= year2020 && epochSeconds <= year2030;
      } catch (e) {
        return false;
      }
    }
    
    return true;
  }
}
