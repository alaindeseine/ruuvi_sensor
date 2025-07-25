import 'dart:typed_data';
import 'models/ruuvi_data.dart';
import 'exceptions/ruuvi_exceptions.dart';

/// Decoder for Ruuvi manufacturer specific data
class RuuviDataDecoder {
  static const int ruuviManufacturerId = 0x0499;
  static const int dataFormat5 = 0x05;
  
  /// Decodes Ruuvi manufacturer specific data from BLE advertisement
  /// 
  /// [manufacturerData] should contain the raw manufacturer data bytes
  /// [deviceId] is the BLE device identifier
  /// [rssi] is the received signal strength indicator
  /// 
  /// Returns a [RuuviData] object with decoded sensor values
  /// Throws [RuuviDataException] if data format is unsupported or invalid
  static RuuviData? decodeManufacturerData(
    Map<int, Uint8List> manufacturerData,
    String deviceId,
    int rssi,
  ) {
    // Check if Ruuvi manufacturer data is present
    final ruuviData = manufacturerData[ruuviManufacturerId];
    if (ruuviData == null || ruuviData.isEmpty) {
      return null;
    }

    // Check data format
    final dataFormat = ruuviData[0];
    if (dataFormat != dataFormat5) {
      throw RuuviDataException(
        'Unsupported data format: $dataFormat. Only format 5 (RAWv2) is supported.',
      );
    }

    if (ruuviData.length < 24) {
      throw RuuviDataException(
        'Invalid data length: ${ruuviData.length}. Expected at least 24 bytes for format 5.',
      );
    }

    return _decodeFormat5(ruuviData, deviceId, rssi);
  }

  /// Decodes Ruuvi data format 5 (RAWv2)
  static RuuviData _decodeFormat5(Uint8List data, String deviceId, int rssi) {
    // Temperature (bytes 1-2): signed 16-bit, 0.005°C per LSB
    final tempRaw = _readInt16(data, 1);
    final temperature = tempRaw == -32768 ? double.nan : tempRaw * 0.005;

    // Humidity (bytes 3-4): unsigned 16-bit, 0.0025% per LSB
    final humidityRaw = _readUint16(data, 3);
    final humidity = humidityRaw == 65535 ? double.nan : humidityRaw * 0.0025;

    // Pressure (bytes 5-6): unsigned 16-bit, 1 Pa per LSB, offset -50000 Pa
    final pressureRaw = _readUint16(data, 5);
    final pressure = pressureRaw == 65535 ? double.nan : (pressureRaw + 50000).toDouble();

    // Acceleration X, Y, Z (bytes 7-12): signed 16-bit, 1 mG per LSB
    final accelX = _readInt16(data, 7);
    final accelY = _readInt16(data, 9);
    final accelZ = _readInt16(data, 11);

    // Power info (bytes 13-14): 11 bits battery voltage + 5 bits TX power
    final powerInfo = _readUint16(data, 13);
    final batteryVoltageRaw = (powerInfo >> 5) & 0x7FF; // First 11 bits
    final txPowerRaw = powerInfo & 0x1F; // Last 5 bits
    
    final batteryVoltage = batteryVoltageRaw == 0x7FF ? null : (batteryVoltageRaw + 1600);
    final txPower = txPowerRaw == 31 ? null : (txPowerRaw * 2 - 40);

    // Movement counter (byte 15)
    final movementCounter = data[15];

    // Measurement sequence number (bytes 16-17)
    final sequenceNumber = _readUint16(data, 16);

    // MAC address (bytes 18-23)
    final macBytes = data.sublist(18, 24);
    final macAddress = macBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();

    return RuuviData(
      deviceId: deviceId,
      serialNumber: macAddress,
      temperature: temperature,
      humidity: humidity,
      pressure: pressure,
      timestamp: DateTime.now(),
      batteryVoltage: batteryVoltage,
      rssi: rssi,
      // Additional fields for format 5
      accelerationX: accelX == -32768 ? null : accelX.toDouble(),
      accelerationY: accelY == -32768 ? null : accelY.toDouble(),
      accelerationZ: accelZ == -32768 ? null : accelZ.toDouble(),
      txPower: txPower,
      movementCounter: movementCounter == 255 ? null : movementCounter,
      sequenceNumber: sequenceNumber == 65535 ? null : sequenceNumber,
    );
  }

  /// Reads a signed 16-bit integer from bytes (MSB first)
  static int _readInt16(Uint8List data, int offset) {
    final value = (data[offset] << 8) | data[offset + 1];
    return value > 32767 ? value - 65536 : value;
  }

  /// Reads an unsigned 16-bit integer from bytes (MSB first)
  static int _readUint16(Uint8List data, int offset) {
    return (data[offset] << 8) | data[offset + 1];
  }
}
