class RuuviData {
  final String deviceId;
  final String? serialNumber;
  final double temperature;
  final double humidity;
  final double pressure;
  final DateTime timestamp;
  final int? batteryVoltage;
  final int? rssi;

  // Additional fields for Ruuvi format 5 (RAWv2)
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;
  final int? txPower;
  final int? movementCounter;
  final int? sequenceNumber;

  const RuuviData({
    required this.deviceId,
    this.serialNumber,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.timestamp,
    this.batteryVoltage,
    this.rssi,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.txPower,
    this.movementCounter,
    this.sequenceNumber,
  });

  @override
  String toString() {
    return 'RuuviData('
        'deviceId: $deviceId, '
        'serialNumber: $serialNumber, '
        'temperature: ${temperature.toStringAsFixed(2)}°C, '
        'humidity: ${humidity.toStringAsFixed(2)}%, '
        'pressure: ${pressure.toStringAsFixed(0)} Pa, '
        'batteryVoltage: ${batteryVoltage}mV, '
        'rssi: ${rssi}dBm'
        ')';
  }
}