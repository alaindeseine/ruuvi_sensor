import 'dart:async';

import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';

import 'exceptions/ruuvi_exceptions.dart';
import 'ruuvi_advertisement_decoder.dart';
import 'ruuvi_permissions.dart';

/// Scanner for RuuviTag advertisements.
///
/// Decodes data formats 3 (RAWv1) and 5 (RAWv2). Tags broadcasting another
/// format are still listed, with [RuuviBleScanResult.dataFormat] set and no
/// sensor values.
class RuuviBleScanner {
  final StreamController<List<RuuviBleScanResult>> _devicesController =
      StreamController<List<RuuviBleScanResult>>.broadcast();

  final Map<String, RuuviBleScanResult> _discoveredDevices = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _timeoutTimer;
  bool _isScanning = false;

  /// Stream of discovered RuuviTag devices.
  ///
  /// Emits the full device list each time an advertisement is received, i.e.
  /// several times per second when tags are nearby. Scan failures are emitted
  /// as [RuuviException] errors.
  Stream<List<RuuviBleScanResult>> get devicesStream =>
      _devicesController.stream;

  /// List of currently discovered devices
  List<RuuviBleScanResult> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices.values.toList());

  /// Whether the scanner is currently scanning
  bool get isScanning => _isScanning;

  /// Starts scanning for RuuviTag devices.
  ///
  /// [timeout] optional duration after which the scan stops by itself.
  /// Throws [RuuviException] if Bluetooth is unavailable, a permission is
  /// denied, or scanning fails to start.
  Future<void> startScan({Duration? timeout}) async {
    if (_isScanning) {
      return; // Already scanning
    }
    _isScanning = true;

    try {
      await ensureBluetoothReady();

      _discoveredDevices.clear();
      _devicesController.add([]);

      _scanSubscription = FlutterBlueUltra.onScanResults.listen(
        _handleScanResults,
        onError: (Object error) {
          _devicesController.addError(RuuviException('Scan error: $error'));
          stopScan();
        },
      );

      // Every advertisement is needed to keep the sensor values fresh.
      await FlutterBlueUltra.startScan(
        withMsd: [MsdFilter(ruuviManufacturerId)],
        continuousUpdates: true,
        oneByOne: true,
      );

      if (timeout != null) {
        _timeoutTimer = Timer(timeout, stopScan);
      }
    } catch (e) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      if (e is RuuviException) rethrow;
      throw RuuviException('Failed to start scan: $e');
    }
  }

  /// Stops the current scan
  Future<void> stopScan() async {
    if (!_isScanning) return;

    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _isScanning = false;
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await FlutterBlueUltra.stopScan();
    } catch (e) {
      throw RuuviException('Failed to stop scan: $e');
    }
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final payload =
          result.advertisementData.manufacturerData[ruuviManufacturerId];
      if (payload == null) continue;

      final data = decodeRuuviAdvertisement(payload);
      if (data == null) continue;

      final deviceId = result.device.remoteId.str;
      final advName = result.advertisementData.advName;
      _discoveredDevices[deviceId] = RuuviBleScanResult(
        deviceId: deviceId,
        name: advName.isNotEmpty ? advName : _fallbackName(deviceId),
        rssi: result.rssi,
        temperature: data.temperature,
        humidity: data.humidity,
        pressure: data.pressure,
        batteryVoltage: data.batteryVoltage,
        dataFormat: data.dataFormat,
        accelerationX: data.accelerationX,
        accelerationY: data.accelerationY,
        accelerationZ: data.accelerationZ,
        txPower: data.txPower,
        movementCounter: data.movementCounter,
        measurementSequence: data.measurementSequence,
        macAddress: data.macAddress,
        lastSeen: DateTime.now(),
      );
    }
    if (!_devicesController.isClosed) {
      _devicesController.add(discoveredDevices);
    }
  }

  static String _fallbackName(String deviceId) {
    final hex = deviceId.replaceAll(':', '').toUpperCase();
    return 'Ruuvi ${hex.length >= 4 ? hex.substring(hex.length - 4) : hex}';
  }

  /// Stops scanning and releases resources.
  void dispose() {
    stopScan().whenComplete(_devicesController.close);
  }
}

/// Result from BLE scan of a RuuviTag.
///
/// Any sensor value is `null` when the tag reports it as unavailable or when
/// its data format doesn't carry it. Equality is based on [deviceId] only.
class RuuviBleScanResult {
  /// Platform identifier of the device (the MAC address on Android).
  final String deviceId;

  /// Advertised name, or `Ruuvi XXXX` (last MAC digits) if none.
  final String name;

  /// Signal strength in dBm.
  final int rssi;

  /// Temperature in °C.
  final double? temperature;

  /// Relative humidity in %.
  final double? humidity;

  /// Pressure in **Pa** (see [pressureHPa]). History values are in hPa.
  final double? pressure;

  /// Battery voltage in mV.
  final int? batteryVoltage;

  /// Advertisement data format (3 = RAWv1, 5 = RAWv2).
  final int? dataFormat;

  /// Acceleration on the X axis in g.
  final double? accelerationX;

  /// Acceleration on the Y axis in g.
  final double? accelerationY;

  /// Acceleration on the Z axis in g.
  final double? accelerationZ;

  /// Transmit power in dBm (RAWv2 only).
  final int? txPower;

  /// Movement counter, incremented by motion interrupts (RAWv2 only).
  final int? movementCounter;

  /// Measurement sequence number (RAWv2 only).
  final int? measurementSequence;

  /// MAC address broadcast in the payload (RAWv2 only).
  final String? macAddress;

  /// When this advertisement was received.
  final DateTime lastSeen;

  const RuuviBleScanResult({
    required this.deviceId,
    required this.name,
    required this.rssi,
    this.temperature,
    this.humidity,
    this.pressure,
    this.batteryVoltage,
    this.dataFormat,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.txPower,
    this.movementCounter,
    this.measurementSequence,
    this.macAddress,
    required this.lastSeen,
  });

  /// Pressure in hPa, the unit used by history measurements.
  double? get pressureHPa => pressure == null ? null : pressure! / 100.0;

  /// Returns a display name for the device
  String get displayName {
    if (name.isNotEmpty && name != deviceId) {
      return name;
    }
    final lastChars = deviceId.replaceAll(':', '').toUpperCase();
    if (lastChars.length >= 4) {
      return 'Ruuvi ${lastChars.substring(lastChars.length - 4)}';
    }
    return 'Ruuvi $lastChars';
  }

  /// Returns true if temperature, humidity and pressure are all available.
  bool get hasValidData {
    return temperature != null && humidity != null && pressure != null;
  }

  @override
  String toString() {
    return 'RuuviBleScanResult(id: $deviceId, name: $displayName, rssi: ${rssi}dBm, '
        'temp: ${temperature?.toStringAsFixed(2)}°C, '
        'humidity: ${humidity?.toStringAsFixed(1)}%, '
        'pressure: ${pressure?.toStringAsFixed(0)}Pa)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuuviBleScanResult && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}
