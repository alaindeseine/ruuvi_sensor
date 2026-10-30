import 'dart:typed_data';

/// Values decoded from a Ruuvi manufacturer-specific advertisement payload.
///
/// Every field is `null` when the payload marks it as "not available"
/// or when the data format doesn't carry it.
class RuuviAdvertisementData {
  final int dataFormat;

  /// Temperature in °C.
  final double? temperature;

  /// Relative humidity in %.
  final double? humidity;

  /// Pressure in Pa.
  final double? pressure;

  /// Acceleration in g.
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;

  /// Battery voltage in mV.
  final int? batteryVoltage;

  /// Transmit power in dBm.
  final int? txPower;
  final int? movementCounter;
  final int? measurementSequence;

  /// MAC address broadcast in the payload, `AA:BB:CC:DD:EE:FF`.
  final String? macAddress;

  const RuuviAdvertisementData({
    required this.dataFormat,
    this.temperature,
    this.humidity,
    this.pressure,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.batteryVoltage,
    this.txPower,
    this.movementCounter,
    this.measurementSequence,
    this.macAddress,
  });
}

/// Ruuvi Innovations Ltd Bluetooth SIG company identifier.
const int ruuviManufacturerId = 0x0499;

/// Decodes a Ruuvi advertisement payload, i.e. the manufacturer data
/// *without* the 2-byte manufacturer ID (first byte is the data format).
///
/// Returns `null` for an empty payload or a known format that is too short.
/// Unknown formats return an object with only [RuuviAdvertisementData.dataFormat].
///
/// Reference: https://docs.ruuvi.com/communication/bluetooth-advertisements
RuuviAdvertisementData? decodeRuuviAdvertisement(List<int> payload) {
  if (payload.isEmpty) return null;
  final data = Uint8List.fromList(payload);
  switch (data[0]) {
    case 0x03:
      return _decodeRawV1(data);
    case 0x05:
      return _decodeRawV2(data);
    default:
      return RuuviAdvertisementData(dataFormat: data[0]);
  }
}

/// RAWv1 (data format 3), 14 bytes.
RuuviAdvertisementData? _decodeRawV1(Uint8List data) {
  if (data.length < 14) return null;
  final bytes = ByteData.sublistView(data);

  // Byte 2: sign bit + integer part, byte 3: hundredths.
  final integer = data[2] & 0x7F;
  final sign = (data[2] & 0x80) != 0 ? -1 : 1;
  final temperature = sign * (integer + data[3] / 100.0);

  return RuuviAdvertisementData(
    dataFormat: 0x03,
    humidity: data[1] * 0.5,
    temperature: temperature,
    pressure: bytes.getUint16(4) + 50000.0,
    accelerationX: bytes.getInt16(6) / 1000.0,
    accelerationY: bytes.getInt16(8) / 1000.0,
    accelerationZ: bytes.getInt16(10) / 1000.0,
    batteryVoltage: bytes.getUint16(12),
  );
}

/// RAWv2 (data format 5), 24 bytes. Each field has an "invalid" sentinel.
RuuviAdvertisementData? _decodeRawV2(Uint8List data) {
  if (data.length < 24) return null;
  final bytes = ByteData.sublistView(data);

  double? acceleration(int offset) {
    final raw = bytes.getInt16(offset);
    return raw == -0x8000 ? null : raw / 1000.0;
  }

  final tempRaw = bytes.getInt16(1);
  final humidityRaw = bytes.getUint16(3);
  final pressureRaw = bytes.getUint16(5);
  final power = bytes.getUint16(13);
  final batteryRaw = power >> 5;
  final txPowerRaw = power & 0x1F;
  final movement = data[15];
  final sequence = bytes.getUint16(16);
  final mac = data.sublist(18, 24);

  return RuuviAdvertisementData(
    dataFormat: 0x05,
    temperature: tempRaw == -0x8000 ? null : tempRaw * 0.005,
    humidity: humidityRaw == 0xFFFF ? null : humidityRaw * 0.0025,
    pressure: pressureRaw == 0xFFFF ? null : pressureRaw + 50000.0,
    accelerationX: acceleration(7),
    accelerationY: acceleration(9),
    accelerationZ: acceleration(11),
    batteryVoltage: batteryRaw == 0x7FF ? null : batteryRaw + 1600,
    txPower: txPowerRaw == 0x1F ? null : -40 + txPowerRaw * 2,
    movementCounter: movement == 0xFF ? null : movement,
    measurementSequence: sequence == 0xFFFF ? null : sequence,
    macAddress: mac.every((b) => b == 0xFF)
        ? null
        : mac
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(':'),
  );
}
