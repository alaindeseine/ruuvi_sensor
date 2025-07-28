import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ruuvi_device.dart';
import 'ruuvi_data_decoder.dart';
import 'ruuvi_permissions.dart';
import 'exceptions/ruuvi_exceptions.dart';

class RuuviScanner {
  static const int _ruuviManufacturerId = 0x0499; // Ruuvi Innovations Ltd

  /// Checks if the device is ready for RuuviTag scanning
  ///
  /// Returns a detailed result with setup instructions if needed
  /// Use this before calling [startScan] to provide better user experience
  static Future<PermissionCheckResult> checkSetup() async {
    return await RuuviPermissions.checkPermissions();
  }

  final StreamController<List<RuuviDevice>> _devicesController =
      StreamController<List<RuuviDevice>>.broadcast();

  final Map<String, RuuviDevice> _discoveredDevices = {};
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  Stream<List<RuuviDevice>> get devicesStream => _devicesController.stream;
  List<RuuviDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices.values.toList());
  bool get isScanning => _isScanning;

  /// Starts scanning for RuuviTag devices
  ///
  /// [timeout] optional timeout duration for the scan
  /// Throws [RuuviException] with detailed setup instructions if permissions are missing
  Future<void> startScan({Duration? timeout}) async {
    print('🔍 RuuviScanner: startScan called with timeout: $timeout');

    if (_isScanning) {
      print('⚠️ RuuviScanner: Already scanning, returning');
      return; // Already scanning
    }

    // Enable verbose logging
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);

    print('🔧 RuuviScanner: Checking permissions...');
    // Check permissions and provide helpful error messages
    final permissionResult = await RuuviPermissions.checkPermissions();
    if (!permissionResult.isReady) {
      print('❌ RuuviScanner: Permissions not ready: ${permissionResult.missingPermissions}');
      throw RuuviPermissions.createPermissionException(permissionResult);
    }
    print('✅ RuuviScanner: Permissions OK');

    // Check adapter state
    print('📡 RuuviScanner: Checking adapter state...');
    final isSupported = await FlutterBluePlus.isSupported;
    print('📡 RuuviScanner: Bluetooth supported: $isSupported');

    final adapterState = await FlutterBluePlus.adapterState.first;
    print('📡 RuuviScanner: Adapter state: $adapterState');

    if (adapterState != BluetoothAdapterState.on) {
      print('❌ RuuviScanner: Adapter not on, current state: $adapterState');
      throw RuuviException('Bluetooth adapter is not on. Current state: $adapterState');
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _devicesController.add([]);
    print('🚀 RuuviScanner: Starting scan process...');

    try {
      print('🔄 RuuviScanner: Calling FlutterBluePlus.startScan...');
      // Start scanning for devices
      await FlutterBluePlus.startScan(
        timeout: timeout, // Can be null for continuous scanning
        androidUsesFineLocation: false,
      );
      print('✅ RuuviScanner: FlutterBluePlus.startScan completed successfully');

      print('👂 RuuviScanner: Setting up scan results listener...');
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          print('📊 RuuviScanner: Received ${results.length} scan results');
          _onScanResult(results);
        },
        onError: (error) {
          print('❌ RuuviScanner: Scan error: $error');
          _isScanning = false;
          _devicesController.addError(RuuviException('Scan error: $error'));
        },
      );
      print('✅ RuuviScanner: Scan results listener set up');

      // Listen for scan completion (only if timeout is set)
      if (timeout != null) {
        print('⏰ RuuviScanner: Setting up scan completion listener for timeout: $timeout');
        FlutterBluePlus.isScanning.listen((scanning) {
          print('🔄 RuuviScanner: Scanning state changed: $scanning');
          if (!scanning && _isScanning) {
            print('🛑 RuuviScanner: Scan completed, setting _isScanning to false');
            _isScanning = false;
          }
        });
      } else {
        print('♾️ RuuviScanner: No timeout set, continuous scanning mode');
      }

      print('🎯 RuuviScanner: Scan setup completed successfully');
    } catch (e) {
      print('💥 RuuviScanner: Exception during scan setup: $e');
      _isScanning = false;
      throw RuuviException('Failed to start scan: $e');
    }
  }

  /// Starts continuous scanning for real-time data updates
  ///
  /// This will scan indefinitely until [stopScan] is called
  /// Perfect for real-time monitoring applications
  Future<void> startContinuousScan() async {
    print('♾️ RuuviScanner: Starting continuous scan (timeout: null)');
    // With Flutter Blue Plus 1.35.5, we can scan without timeout for continuous updates
    return startScan(timeout: null);
  }

  /// Stops the current scan
  Future<void> stopScan() async {
    if (!_isScanning) {
      return; // Not scanning
    }

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
    } catch (e) {
      throw RuuviException('Failed to stop scan: $e');
    }
  }

  /// Handles scan results and filters for RuuviTag devices
  void _onScanResult(List<ScanResult> results) {
    print('🔍 RuuviScanner._onScanResult: Processing ${results.length} results');
    bool devicesUpdated = false;

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      print('📱 RuuviScanner: Processing device ${i + 1}/${results.length}: ${result.device.remoteId.str}');
      print('   - Name: "${result.advertisementData.advName}"');
      print('   - RSSI: ${result.rssi}');
      print('   - Manufacturer data keys: ${result.advertisementData.manufacturerData.keys.toList()}');

      try {
        // Check if this is a Ruuvi device by looking for manufacturer data
        final manufacturerData = result.advertisementData.manufacturerData;
        if (!manufacturerData.containsKey(_ruuviManufacturerId)) {
          print('   ❌ Not a Ruuvi device (no manufacturer ID 0x${_ruuviManufacturerId.toRadixString(16)})');
          continue; // Not a Ruuvi device
        }

        print('   ✅ Found Ruuvi device! Manufacturer ID: 0x${_ruuviManufacturerId.toRadixString(16)}');

        // Convert manufacturer data to Uint8List format
        final convertedManufacturerData = <int, Uint8List>{};
        manufacturerData.forEach((key, value) {
          convertedManufacturerData[key] = Uint8List.fromList(value);
          print('   📊 Manufacturer data 0x${key.toRadixString(16)}: ${value.length} bytes: ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        });

        print('   🔧 Attempting to decode Ruuvi data...');
        // Try to decode the Ruuvi data
        final ruuviData = RuuviDataDecoder.decodeManufacturerData(
          convertedManufacturerData,
          result.device.remoteId.str,
          result.rssi,
        );

        if (ruuviData == null) {
          print('   ❌ Failed to decode Ruuvi data');
          continue; // Failed to decode
        }

        print('   ✅ Successfully decoded Ruuvi data: T=${ruuviData.temperature.toStringAsFixed(1)}°C, H=${ruuviData.humidity.toStringAsFixed(1)}%, P=${ruuviData.pressure.toStringAsFixed(0)}Pa');

        // Create or update RuuviDevice
        final deviceId = result.device.remoteId.str;
        final existingDevice = _discoveredDevices[deviceId];

        if (existingDevice == null) {
          print('   🆕 New Ruuvi device discovered: $deviceId');
          // New device discovered
          final ruuviDevice = RuuviDevice(
            device: result.device,
            serialNumber: ruuviData.serialNumber ?? deviceId,
            rssi: result.rssi,
            lastData: ruuviData,
          );

          _discoveredDevices[deviceId] = ruuviDevice;
          devicesUpdated = true;
          print('   ✅ Added to discovered devices list (total: ${_discoveredDevices.length})');
        } else {
          print('   🔄 Updating existing device: $deviceId');
          // Update existing device with new data
          existingDevice.updateData(ruuviData, result.rssi);
          print('   ✅ Device data updated');
        }
      } catch (e) {
        print('   💥 Exception processing device: $e');
        // Ignore devices that can't be decoded (might be old format or corrupted data)
        continue;
      }
    }

    print('🔍 RuuviScanner._onScanResult: Finished processing. Devices updated: $devicesUpdated, Total devices: ${_discoveredDevices.length}');

    // Notify listeners if devices were updated
    if (devicesUpdated) {
      print('📢 RuuviScanner: Notifying listeners with ${discoveredDevices.length} devices');
      _devicesController.add(discoveredDevices);
    } else {
      print('📢 RuuviScanner: No new devices, not notifying listeners');
    }
  }

  /// Disposes of resources
  void dispose() {
    _scanSubscription?.cancel();
    _devicesController.close();
  }
}