import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'exceptions/ruuvi_exceptions.dart';

/// Scanner for RuuviTag devices using flutter_reactive_ble
class RuuviBleScanner {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  static const int _ruuviManufacturerId = 0x0499; // Ruuvi Innovations Ltd
  
  final StreamController<List<RuuviBleScanResult>> _devicesController =
      StreamController<List<RuuviBleScanResult>>.broadcast();
  
  final Map<String, RuuviBleScanResult> _discoveredDevices = {};
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  bool _isScanning = false;
  
  /// Stream of discovered RuuviTag devices
  Stream<List<RuuviBleScanResult>> get devicesStream => _devicesController.stream;
  
  /// List of currently discovered devices
  List<RuuviBleScanResult> get discoveredDevices => 
      List.unmodifiable(_discoveredDevices.values.toList());
  
  /// Whether the scanner is currently scanning
  bool get isScanning => _isScanning;
  
  /// Starts scanning for RuuviTag devices
  ///
  /// [timeout] optional timeout duration for the scan
  /// Throws [RuuviException] if scanning fails
  Future<void> startScan({Duration? timeout}) async {
    if (_isScanning) {
      return; // Already scanning
    }
    
    try {
      _isScanning = true;
      _discoveredDevices.clear();
      _devicesController.add([]);
      
      // Start scanning for devices with Ruuvi manufacturer data
      _scanSubscription = _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: false,
      ).listen(
        (device) {
          _handleDiscoveredDevice(device);
        },
        onError: (error) {
          throw RuuviException('Scan error: $error');
        },
      );
      
      // Set timeout if provided
      if (timeout != null) {
        Timer(timeout, () {
          stopScan();
        });
      }
      
    } catch (e) {
      _isScanning = false;
      throw RuuviException('Failed to start scan: $e');
    }
  }
  
  /// Stops the current scan
  Future<void> stopScan() async {
    if (!_isScanning) return;
    
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
    } catch (e) {
      throw RuuviException('Failed to stop scan: $e');
    }
  }
  
  /// Handles a discovered device and checks if it's a RuuviTag
  void _handleDiscoveredDevice(DiscoveredDevice device) {
    try {
      // Check if device has manufacturer data
      final manufacturerData = device.manufacturerData;
      if (manufacturerData.isEmpty) return;
      
      // Look for Ruuvi manufacturer ID (0x0499)
      Uint8List? ruuviData;
      for (final entry in manufacturerData.entries) {
        if (entry.key == _ruuviManufacturerId) {
          ruuviData = Uint8List.fromList(entry.value);
          break;
        }
      }
      
      if (ruuviData == null) return;
      
      // Parse Ruuvi data
      final parsedData = _parseRuuviData(ruuviData);
      if (parsedData == null) return;
      
      // Create or update scan result
      final scanResult = RuuviBleScanResult(
        deviceId: device.id,
        name: device.name.isNotEmpty ? device.name : 'Ruuvi ${device.id.substring(device.id.length - 4)}',
        rssi: device.rssi,
        temperature: parsedData['temperature'],
        humidity: parsedData['humidity'],
        pressure: parsedData['pressure'],
        batteryVoltage: parsedData['batteryVoltage'],
        dataFormat: parsedData['dataFormat'],
        lastSeen: DateTime.now(),
      );
      
      // Update discovered devices
      _discoveredDevices[device.id] = scanResult;
      _devicesController.add(discoveredDevices);
      
    } catch (e) {
      // Ignore parsing errors for individual devices
    }
  }
  
  /// Parses Ruuvi manufacturer data
  Map<String, dynamic>? _parseRuuviData(Uint8List data) {
    if (data.length < 2) return null;
    
    final dataFormat = data[0];
    
    try {
      switch (dataFormat) {
        case 0x03: // RAWv1
          return _parseRAWv1(data);
        case 0x05: // RAWv2
          return _parseRAWv2(data);
        default:
          return {
            'dataFormat': dataFormat,
            'temperature': double.nan,
            'humidity': double.nan,
            'pressure': double.nan,
            'batteryVoltage': null,
          };
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Parses RAWv1 format (0x03)
  Map<String, dynamic> _parseRAWv1(Uint8List data) {
    if (data.length < 14) return {};
    
    final buffer = ByteData.sublistView(data);
    
    // Temperature (bytes 2-3, signed, big-endian)
    final tempRaw = buffer.getInt16(2, Endian.big);
    final temperature = tempRaw / 100.0;
    
    // Humidity (bytes 4-5, unsigned, big-endian)
    final humidityRaw = buffer.getUint16(4, Endian.big);
    final humidity = humidityRaw / 100.0;
    
    // Pressure (bytes 6-7, unsigned, big-endian)
    final pressureRaw = buffer.getUint16(6, Endian.big);
    final pressure = pressureRaw + 50000.0; // Pa
    
    return {
      'dataFormat': 0x03,
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'batteryVoltage': null,
    };
  }
  
  /// Parses RAWv2 format (0x05)
  Map<String, dynamic> _parseRAWv2(Uint8List data) {
    if (data.length < 24) return {};
    
    final buffer = ByteData.sublistView(data);
    
    // Temperature (bytes 3-4, signed, big-endian)
    final tempRaw = buffer.getInt16(3, Endian.big);
    final temperature = tempRaw * 0.005;
    
    // Humidity (bytes 5-6, unsigned, big-endian)
    final humidityRaw = buffer.getUint16(5, Endian.big);
    final humidity = humidityRaw * 0.0025;
    
    // Pressure (bytes 7-8, unsigned, big-endian)
    final pressureRaw = buffer.getUint16(7, Endian.big);
    final pressure = (pressureRaw + 50000.0); // Pa
    
    // Battery voltage (bytes 15-16, unsigned, big-endian)
    final batteryRaw = buffer.getUint16(15, Endian.big);
    final batteryVoltage = (batteryRaw >> 5) + 1600; // mV
    
    return {
      'dataFormat': 0x05,
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'batteryVoltage': batteryVoltage,
    };
  }
  
  /// Disposes the scanner and cleans up resources
  void dispose() {
    stopScan();
    _devicesController.close();
  }
}

/// Result from BLE scan of a RuuviTag
class RuuviBleScanResult {
  final String deviceId;
  final String name;
  final int rssi;
  final double? temperature;
  final double? humidity;
  final double? pressure;
  final int? batteryVoltage;
  final int? dataFormat;
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
    required this.lastSeen,
  });
  
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
  
  /// Returns true if the device has valid sensor data
  bool get hasValidData {
    return temperature != null && !temperature!.isNaN &&
           humidity != null && !humidity!.isNaN &&
           pressure != null && !pressure!.isNaN;
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
