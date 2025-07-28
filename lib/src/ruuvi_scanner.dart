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
    if (_isScanning) {
      return; // Already scanning
    }

    // Check permissions and provide helpful error messages
    final permissionResult = await RuuviPermissions.checkPermissions();
    if (!permissionResult.isReady) {
      throw RuuviPermissions.createPermissionException(permissionResult);
    }

    _isScanning = true;
    _discoveredDevices.clear();
    _devicesController.add([]);

    try {
      // Start scanning for devices
      await FlutterBluePlus.startScan(
        timeout: timeout, // Can be null for continuous scanning
        androidUsesFineLocation: false,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResult,
        onError: (error) {
          _isScanning = false;
          _devicesController.addError(RuuviException('Scan error: $error'));
        },
      );

      // Listen for scan completion (only if timeout is set)
      if (timeout != null) {
        FlutterBluePlus.isScanning.listen((scanning) {
          if (!scanning && _isScanning) {
            _isScanning = false;
          }
        });
      }
    } catch (e) {
      _isScanning = false;
      throw RuuviException('Failed to start scan: $e');
    }
  }

  /// Starts continuous scanning for real-time data updates
  ///
  /// This will scan indefinitely until [stopScan] is called
  /// Perfect for real-time monitoring applications
  Future<void> startContinuousScan() async {
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
    bool devicesUpdated = false;

    for (final result in results) {
      try {
        // Check if this is a Ruuvi device by looking for manufacturer data
        final manufacturerData = result.advertisementData.manufacturerData;
        if (!manufacturerData.containsKey(_ruuviManufacturerId)) {
          continue; // Not a Ruuvi device
        }

        // Convert manufacturer data to Uint8List format
        final convertedManufacturerData = <int, Uint8List>{};
        manufacturerData.forEach((key, value) {
          convertedManufacturerData[key] = Uint8List.fromList(value);
        });

        // Try to decode the Ruuvi data
        final ruuviData = RuuviDataDecoder.decodeManufacturerData(
          convertedManufacturerData,
          result.device.remoteId.str,
          result.rssi,
        );

        if (ruuviData == null) {
          continue; // Failed to decode
        }

        // Create or update RuuviDevice
        final deviceId = result.device.remoteId.str;
        final existingDevice = _discoveredDevices[deviceId];

        if (existingDevice == null) {
          // New device discovered
          final ruuviDevice = RuuviDevice(
            device: result.device,
            serialNumber: ruuviData.serialNumber ?? deviceId,
            rssi: result.rssi,
            lastData: ruuviData,
          );

          _discoveredDevices[deviceId] = ruuviDevice;
          devicesUpdated = true;
        } else {
          // Update existing device with new data
          existingDevice.updateData(ruuviData, result.rssi);
        }
      } catch (e) {
        // Ignore devices that can't be decoded (might be old format or corrupted data)
        continue;
      }
    }

    // Notify listeners if devices were updated
    if (devicesUpdated) {
      _devicesController.add(discoveredDevices);
    }
  }

  /// Disposes of resources
  void dispose() {
    _scanSubscription?.cancel();
    _devicesController.close();
  }
}