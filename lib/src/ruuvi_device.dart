import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/ruuvi_data.dart';
import 'models/ruuvi_measurement.dart';
import 'ruuvi_log_reader.dart';
import 'ruuvi_history_parser.dart';
import 'exceptions/ruuvi_exceptions.dart';

class RuuviDevice {
  // Nordic UART Service UUIDs
  static const String _nusServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _nusTxCharacteristicUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // Write to device
  static const String _nusRxCharacteristicUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // Read from device

  final BluetoothDevice device;
  final String serialNumber;
  int _rssi;
  RuuviData? _lastData;

  // Connection state
  bool _isConnected = false;
  BluetoothService? _nusService;
  BluetoothCharacteristic? _txCharacteristic; // Write to device (6E400002)
  BluetoothCharacteristic? _rxCharacteristic; // Read from device (6E400003)
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;

  // Response stream for log reading
  final StreamController<Uint8List> _responseController = StreamController<Uint8List>.broadcast();

  RuuviDevice({
    required this.device,
    required this.serialNumber,
    required int rssi,
    RuuviData? lastData,
  }) : _rssi = rssi, _lastData = lastData;

  /// Current RSSI value
  int get rssi => _rssi;

  /// Last received sensor data
  RuuviData? get lastData => _lastData;

  /// Whether the device is currently connected
  bool get isConnected => _isConnected;

  /// Device name for display
  String get name => device.platformName.isNotEmpty
      ? device.platformName
      : 'Ruuvi ${serialNumber.substring(serialNumber.length - 4)}';

  /// Updates the device with new sensor data
  void updateData(RuuviData newData, int newRssi) {
    _lastData = newData;
    _rssi = newRssi;
  }

  /// Reads device information including firmware version
  Future<Map<String, String>> readDeviceInfo() async {
    final deviceInfo = <String, String>{};

    try {
      print('📋 RuuviDevice: Reading device information...');

      // Check if device is connected
      if (!device.isConnected) {
        throw RuuviException('Device not connected');
      }

      // Discover services if not already done
      final services = await device.discoverServices();
      print('📋 RuuviDevice: Found ${services.length} services');

      // Look for Device Information Service (0x180A)
      final deviceInfoService = services.where((s) =>
        s.uuid.toString().toLowerCase() == '0000180a-0000-1000-8000-00805f9b34fb').firstOrNull;

      if (deviceInfoService != null) {
        print('📋 RuuviDevice: Found Device Information Service');

        // Read serial number (0x2A25) - PRIORITY
        final serialChar = deviceInfoService.characteristics.where((c) =>
          c.uuid.toString().toLowerCase() == '00002a25-0000-1000-8000-00805f9b34fb').firstOrNull;

        if (serialChar != null) {
          final serialData = await serialChar.read();
          deviceInfo['serial_number'] = String.fromCharCodes(serialData);
          print('📋 RuuviDevice: Serial Number: ${deviceInfo['serial_number']}');
        }

        // Read firmware revision (0x2A26)
        final firmwareChar = deviceInfoService.characteristics.where((c) =>
          c.uuid.toString().toLowerCase() == '00002a26-0000-1000-8000-00805f9b34fb').firstOrNull;

        if (firmwareChar != null) {
          final firmwareData = await firmwareChar.read();
          deviceInfo['firmware'] = String.fromCharCodes(firmwareData);
          print('📋 RuuviDevice: Firmware version: ${deviceInfo['firmware']}');
        }

        // Read hardware revision (0x2A27)
        final hardwareChar = deviceInfoService.characteristics.where((c) =>
          c.uuid.toString().toLowerCase() == '00002a27-0000-1000-8000-00805f9b34fb').firstOrNull;

        if (hardwareChar != null) {
          final hardwareData = await hardwareChar.read();
          deviceInfo['hardware'] = String.fromCharCodes(hardwareData);
          print('📋 RuuviDevice: Hardware version: ${deviceInfo['hardware']}');
        }

        // Read manufacturer name (0x2A29)
        final manufacturerChar = deviceInfoService.characteristics.where((c) =>
          c.uuid.toString().toLowerCase() == '00002a29-0000-1000-8000-00805f9b34fb').firstOrNull;

        if (manufacturerChar != null) {
          final manufacturerData = await manufacturerChar.read();
          deviceInfo['manufacturer'] = String.fromCharCodes(manufacturerData);
          print('📋 RuuviDevice: Manufacturer: ${deviceInfo['manufacturer']}');
        }
      } else {
        print('📋 RuuviDevice: Device Information Service not found');
        print('📋 RuuviDevice: Using fallback methods for device info...');

        // Fallback: Use device ID as serial number if DIS not available
        deviceInfo['serial_number_fallback'] = device.remoteId.str;
        print('📋 RuuviDevice: Serial Number (fallback): ${deviceInfo['serial_number_fallback']}');
      }

      // Also try to read device name from GAP service (0x1800)
      final gapService = services.where((s) =>
        s.uuid.toString().toLowerCase() == '00001800-0000-1000-8000-00805f9b34fb').firstOrNull;

      if (gapService != null) {
        final deviceNameChar = gapService.characteristics.where((c) =>
          c.uuid.toString().toLowerCase() == '00002a00-0000-1000-8000-00805f9b34fb').firstOrNull;

        if (deviceNameChar != null) {
          final nameData = await deviceNameChar.read();
          deviceInfo['device_name'] = String.fromCharCodes(nameData);
          print('📋 RuuviDevice: Device name: ${deviceInfo['device_name']}');
        }
      }

    } catch (e) {
      print('❌ RuuviDevice: Error reading device info: $e');
      throw RuuviException('Failed to read device information: $e');
    }

    return deviceInfo;
  }

  /// Reads all available information from Device Information Service (180A)
  Future<Map<String, String>> readDeviceInformationService() async {
    final deviceInfo = <String, String>{};

    try {
      print('📋 RuuviDevice: Reading Device Information Service...');

      if (!device.isConnected) {
        throw RuuviException('Device not connected');
      }

      final services = await device.discoverServices();
      final deviceInfoService = services.where((s) =>
        s.uuid.toString().toLowerCase().contains('180a')).firstOrNull;

      if (deviceInfoService != null) {
        print('📋 RuuviDevice: Found Device Information Service: ${deviceInfoService.uuid}');

        // Map of characteristic UUIDs to their names
        final characteristics = {
          '2a25': 'serial_number',      // Serial Number String
          '2a26': 'firmware_revision',  // Firmware Revision String
          '2a27': 'hardware_revision',  // Hardware Revision String
          '2a29': 'manufacturer_name',  // Manufacturer Name String
          '2a24': 'model_number',       // Model Number String
        };

        for (final entry in characteristics.entries) {
          final uuid = entry.key;
          final name = entry.value;

          final char = deviceInfoService.characteristics.where((c) =>
            c.uuid.toString().toLowerCase().contains(uuid)).firstOrNull;

          if (char != null) {
            try {
              final data = await char.read();
              final value = String.fromCharCodes(data);
              deviceInfo[name] = value;
              print('📋 RuuviDevice: $name ($uuid): "$value"');
            } catch (e) {
              print('❌ RuuviDevice: Failed to read $name ($uuid): $e');
              deviceInfo[name] = 'Error: $e';
            }
          } else {
            print('📋 RuuviDevice: Characteristic $name ($uuid) not found');
          }
        }

        if (deviceInfo.isEmpty) {
          print('📋 RuuviDevice: No readable characteristics found in Device Information Service');
        }

      } else {
        print('📋 RuuviDevice: Device Information Service (180A) not found');
        deviceInfo['error'] = 'Device Information Service not available';
      }

    } catch (e) {
      print('❌ RuuviDevice: Error reading Device Information Service: $e');
      deviceInfo['error'] = 'Failed to read Device Information Service: $e';
    }

    return deviceInfo;
  }

  /// Reads the serial number specifically
  /// Returns the serial number from Device Information Service or fallback to device ID
  Future<String> readSerialNumber() async {
    try {
      print('📋 RuuviDevice: Reading serial number...');

      // Check if device is connected
      if (!device.isConnected) {
        throw RuuviException('Device not connected');
      }

      // Try to read serial number directly using the correct approach
      try {
        // Find Device Information Service (180A)
        final services = await device.discoverServices();
        final deviceInfoService = services.where((s) =>
          s.uuid.toString().toLowerCase().contains('180a')).firstOrNull;

        if (deviceInfoService != null) {
          print('📋 RuuviDevice: Found Device Information Service: ${deviceInfoService.uuid}');

          // Find Serial Number characteristic (2A25)
          final serialChar = deviceInfoService.characteristics.where((c) =>
            c.uuid.toString().toLowerCase().contains('2a25')).firstOrNull;

          if (serialChar != null) {
            print('📋 RuuviDevice: Found Serial Number characteristic: ${serialChar.uuid}');

            // Read the serial number
            final serialData = await serialChar.read();
            final serialNumber = String.fromCharCodes(serialData);
            print('📋 RuuviDevice: Serial Number: "$serialNumber"');
            return serialNumber;
          } else {
            print('📋 RuuviDevice: Serial Number characteristic (2A25) not found');
            // List all characteristics for debugging
            for (final char in deviceInfoService.characteristics) {
              print('📋 RuuviDevice: Available characteristic: ${char.uuid}');
            }
          }
        } else {
          print('📋 RuuviDevice: Device Information Service (180A) not found');
          // List all services for debugging
          for (final service in services) {
            print('📋 RuuviDevice: Available service: ${service.uuid}');
          }
        }
      } catch (e) {
        print('❌ RuuviDevice: Error reading from Device Information Service: $e');
      }

      // Fallback: Use device ID
      final fallbackSerial = device.remoteId.str;
      print('📋 RuuviDevice: Using device ID as serial number: $fallbackSerial');
      return fallbackSerial;

    } catch (e) {
      print('❌ RuuviDevice: Error reading serial number: $e');
      // Return device ID as ultimate fallback
      return device.remoteId.str;
    }
  }

  /// Connects to the RuuviTag device
  ///
  /// Establishes a GATT connection and discovers the Nordic UART Service
  /// Throws [RuuviConnectionException] if connection fails
  Future<void> connect() async {
    if (_isConnected) {
      return; // Already connected
    }

    try {
      // Connect to the device
      await device.connect(timeout: const Duration(seconds: 15));

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        _isConnected = state == BluetoothConnectionState.connected;
        if (!_isConnected) {
          _cleanup();
        }
      });

      // Discover services
      final services = await device.discoverServices();

      // Find Nordic UART Service
      _nusService = services.firstWhere(
        (service) => service.uuid.toString().toUpperCase() == _nusServiceUuid.toUpperCase(),
        orElse: () => throw RuuviConnectionException('Nordic UART Service not found'),
      );

      // Find characteristics
      _txCharacteristic = _nusService!.characteristics.firstWhere(
        (char) => char.uuid.toString().toUpperCase() == _nusTxCharacteristicUuid.toUpperCase(),
        orElse: () => throw RuuviConnectionException('TX characteristic not found'),
      );

      _rxCharacteristic = _nusService!.characteristics.firstWhere(
        (char) => char.uuid.toString().toUpperCase() == _nusRxCharacteristicUuid.toUpperCase(),
        orElse: () => throw RuuviConnectionException('RX characteristic not found'),
      );

      // Enable notifications on RX characteristic (read from device)
      await _rxCharacteristic!.setNotifyValue(true);

      // Listen for notifications (responses from device)
      _notificationSubscription = _txCharacteristic!.lastValueStream.listen(
        (value) => _responseController.add(Uint8List.fromList(value)),
      );

      _isConnected = true;
    } catch (e) {
      _cleanup();
      if (e is RuuviConnectionException) {
        rethrow;
      }
      throw RuuviConnectionException('Failed to connect: $e');
    }
  }

  /// Retrieves stored historical data from the device using Cut-RAWv2 format
  ///
  /// [timeout] timeout for the operation (defaults to 30 seconds)
  ///
  /// Returns [RuuviMeasurement] containing all retrieved historical data
  /// Throws [RuuviConnectionException] if not connected
  /// Throws [RuuviDataException] if data retrieval fails
  Future<RuuviMeasurement> getStoredData({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isConnected || _txCharacteristic == null || _rxCharacteristic == null) {
      throw RuuviConnectionException('Device not connected or NUS not available');
    }

    print('📚 RuuviDevice: Starting historical data retrieval...');

    final historyData = <int>[];
    final completer = Completer<RuuviMeasurement>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;

    try {
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print('⏰ RuuviDevice: History read timeout after ${timeout.inSeconds} seconds');
          completer.completeError(
            RuuviDataException('History read timeout after ${timeout.inSeconds} seconds'),
          );
        }
      });

      // Listen for responses
      subscription = _rxCharacteristic!.lastValueStream.listen((data) {
        if (data.isNotEmpty) {
          print('📥 RuuviDevice: Received ${data.length} bytes: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
          historyData.addAll(data);

          // Check if we have complete 10-byte entries
          if (historyData.length >= 10 && historyData.length % 10 == 0) {
            // Try to parse what we have so far
            final currentData = Uint8List.fromList(historyData);
            if (RuuviHistoryParser.isValidHistoryData(currentData)) {
              print('✅ RuuviDevice: Received valid history data, continuing...');
            }
          }
        }
      });

      // Send history command (try 0x03 first)
      final historyCommand = Uint8List.fromList([0x03]);
      print('📤 RuuviDevice: Sending history command: 0x03');
      await _sendCommand(historyCommand);

      // Wait a bit for initial response
      await Future.delayed(const Duration(milliseconds: 500));

      // If no data received, try alternative commands
      if (historyData.isEmpty) {
        print('📤 RuuviDevice: No response to 0x03, trying 0x05...');
        final altCommand1 = Uint8List.fromList([0x05]);
        await _sendCommand(altCommand1);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (historyData.isEmpty) {
        print('📤 RuuviDevice: No response to 0x05, trying 0x80...');
        final altCommand2 = Uint8List.fromList([0x80]);
        await _sendCommand(altCommand2);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Wait for more data or timeout
      await Future.delayed(Duration(seconds: timeout.inSeconds - 2));

      if (!completer.isCompleted) {
        // Process collected data
        if (historyData.isNotEmpty) {
          print('📊 RuuviDevice: Processing ${historyData.length} bytes of collected data');
          final parsedData = RuuviHistoryParser.parseHistoryData(Uint8List.fromList(historyData), device.remoteId.str);

          final now = DateTime.now();
          final measurement = RuuviMeasurement(
            measurements: parsedData,
            startTime: parsedData.isNotEmpty ? parsedData.first.timestamp : now,
            endTime: parsedData.isNotEmpty ? parsedData.last.timestamp : now,
            totalCount: parsedData.length,
          );

          completer.complete(measurement);
        } else {
          completer.completeError(
            RuuviDataException('No historical data received from device'),
          );
        }
      }

    } catch (e) {
      if (!completer.isCompleted) {
        print('❌ RuuviDevice: Error during history retrieval: $e');
        completer.completeError(RuuviDataException('Failed to retrieve historical data: $e'));
      }
    } finally {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    return completer.future;
  }

  /// Disconnects from the device
  Future<void> disconnect() async {
    if (!_isConnected) {
      return; // Already disconnected
    }

    try {
      await device.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    } finally {
      _cleanup();
    }
  }

  /// Sends a command to the device via Nordic UART Service
  ///
  /// [data] the command data to send (max 20 bytes)
  /// Throws [RuuviConnectionException] if not connected or send fails
  Future<void> _sendCommand(Uint8List data) async {
    if (!_isConnected || _txCharacteristic == null) {
      throw RuuviConnectionException('Device not connected');
    }

    if (data.length > 20) {
      throw RuuviConnectionException('Command data too long (max 20 bytes)');
    }

    try {
      print('📤 RuuviDevice: Sending command: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      await _txCharacteristic!.write(data, withoutResponse: false);
      print('📤 RuuviDevice: Command sent successfully');
    } catch (e) {
      print('❌ RuuviDevice: Failed to send command: $e');
      throw RuuviConnectionException('Failed to send command: $e');
    }
  }

  /// Cleans up connection resources
  void _cleanup() {
    _isConnected = false;
    _nusService = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  /// Disposes of all resources
  void dispose() {
    _cleanup();
    _responseController.close();
  }

  @override
  String toString() {
    return 'RuuviDevice(name: $name, serialNumber: $serialNumber, rssi: ${rssi}dBm)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuuviDevice && other.device.remoteId == device.remoteId;
  }

  @override
  int get hashCode => device.remoteId.hashCode;
}
