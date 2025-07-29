import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'models/ruuvi_tag_information.dart';
import 'models/ruuvi_history_measurement.dart';
import 'exceptions/ruuvi_exceptions.dart';

/// Reader for RuuviTag historical data using flutter_reactive_ble
class RuuviHistoryReader {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Nordic UART Service UUIDs
  static final Uuid _nusServiceUuid = Uuid.parse('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Uuid _rxCharacteristicUuid = Uuid.parse('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Uuid _txCharacteristicUuid = Uuid.parse('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  // Device Information Service UUIDs (for reference)
  // static final Uuid _deviceInfoServiceUuid = Uuid.parse('0000180a-0000-1000-8000-00805f9b34fb');

  /// Reads device information from a RuuviTag
  ///
  /// Returns [RuuviTagInformation] with device details
  /// Throws [RuuviConnectionException] if connection fails
  /// Throws [RuuviDataException] if data reading fails
  Future<RuuviTagInformation> getDeviceInformation(String deviceId) async {
    try {
      // Connect to device
      _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 10),
      );

      String? serialNumber;
      String? manufacturer;
      String? model;
      String? firmwareVersion;
      String? hardwareVersion;

      try {
        // Discover services
        await _ble.discoverAllServices(deviceId);
        final services = await _ble.getDiscoveredServices(deviceId);

        // Find Device Information Service
        final deviceInfoService = services.where((s) =>
            s.id.toString().toLowerCase().contains('180a')).firstOrNull;

        if (deviceInfoService != null) {
          // Read all available characteristics
          for (final char in deviceInfoService.characteristics) {
            try {
              final data = await _ble.readCharacteristic(
                QualifiedCharacteristic(
                  serviceId: deviceInfoService.id,
                  characteristicId: char.id,
                  deviceId: deviceId,
                ),
              );
              final value = String.fromCharCodes(data);
              final charId = char.id.toString().toLowerCase();

              if (charId.contains('2a25')) {
                serialNumber = value;
              } else if (charId.contains('2a29')) {
                manufacturer = value;
              } else if (charId.contains('2a24')) {
                model = value;
              } else if (charId.contains('2a26')) {
                firmwareVersion = value;
              } else if (charId.contains('2a27')) {
                hardwareVersion = value;
              }
            } catch (e) {
              // Ignore individual characteristic read errors
              continue;
            }
          }
        }
      } catch (e) {
        // Service discovery failed, but we can still return basic info
      }

      // Use serial number if available, otherwise fallback to MAC address
      final identifier = serialNumber ?? deviceId;

      return RuuviTagInformation(
        identifier: identifier,
        macAddress: deviceId,
        manufacturer: manufacturer,
        model: model,
        firmwareVersion: firmwareVersion,
        hardwareVersion: hardwareVersion,
      );

    } catch (e) {
      throw RuuviConnectionException('Failed to read device information: $e');
    }
  }

  /// Reads historical data from a RuuviTag
  ///
  /// [deviceId] MAC address of the RuuviTag
  /// [startDate] optional start date (defaults to 7 days ago)
  /// [endDate] optional end date (defaults to now)
  ///
  /// Returns [RuuviHistoryCollection] with historical measurements
  /// Throws [RuuviConnectionException] if connection fails
  /// Throws [RuuviDataException] if data reading fails
  Future<RuuviHistoryCollection> getHistory(
    String deviceId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final measurements = <RuuviHistoryMeasurement>[];
    
    try {
      // Connect to device
      _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 10),
      );

      // Prepare time range
      final now = DateTime.now();
      final end = endDate ?? now;
      final start = startDate ?? now.subtract(const Duration(days: 7));

      // Prepare history command
      final currentTime = (end.millisecondsSinceEpoch / 1000).round();
      final startTime = (start.millisecondsSinceEpoch / 1000).round();

      final command = [
        0x3A, 0x3A, 0x11,
        (currentTime >> 24) & 0xFF, (currentTime >> 16) & 0xFF, 
        (currentTime >> 8) & 0xFF, currentTime & 0xFF,
        (startTime >> 24) & 0xFF, (startTime >> 16) & 0xFF, 
        (startTime >> 8) & 0xFF, startTime & 0xFF,
      ];

      // Setup completion detection
      final completer = Completer<void>();
      DateTime lastDataReceived = DateTime.now();

      // Temporary storage for grouping measurements by timestamp
      final Map<int, Map<String, double>> measurementGroups = {};

      // Timer for silence detection
      Timer? silenceTimer;
      silenceTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        final silenceDuration = DateTime.now().difference(lastDataReceived);
        if (silenceDuration.inSeconds > 10) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          timer.cancel();
        }
      });

      // Global timeout timer
      Timer? globalTimer;
      globalTimer = Timer(const Duration(seconds: 120), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
        silenceTimer?.cancel();
      });

      // Subscribe to notifications
      final characteristic = QualifiedCharacteristic(
        serviceId: _nusServiceUuid,
        characteristicId: _txCharacteristicUuid,
        deviceId: deviceId,
      );

      final subscription = _ble.subscribeToCharacteristic(characteristic).listen(
        (data) {
          lastDataReceived = DateTime.now();

          // Parse Ruuvi Log Response (11 bytes)
          if (data.length == 11) {
            final parsedData = _parseRuuviLogResponse(Uint8List.fromList(data));
            if (parsedData != null) {
              if (parsedData['isEndMarker'] == true) {
                // End of history detected
                if (!completer.isCompleted) {
                  completer.complete();
                }
                return;
              }

              // Group measurements by timestamp
              final timestamp = parsedData['timestamp'] as int;
              final sensorType = parsedData['sensorType'] as String;
              final value = parsedData['value'] as double;

              measurementGroups[timestamp] ??= {};
              measurementGroups[timestamp]![sensorType] = value;
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Send history command
      final txCharacteristic = QualifiedCharacteristic(
        serviceId: _nusServiceUuid,
        characteristicId: _rxCharacteristicUuid,
        deviceId: deviceId,
      );

      await _ble.writeCharacteristicWithoutResponse(txCharacteristic, value: command);

      // Wait for completion
      await completer.future;

      // Clean up timers and subscription
      silenceTimer.cancel();
      globalTimer.cancel();
      await subscription.cancel();

      // Convert grouped measurements to RuuviHistoryMeasurement objects
      for (final entry in measurementGroups.entries) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(entry.key * 1000);
        final values = entry.value;

        measurements.add(RuuviHistoryMeasurement(
          timestamp: timestamp,
          temperature: values['temperature'],
          humidity: values['humidity'],
          pressure: values['pressure'],
        ));
      }

      // Sort by timestamp
      measurements.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return RuuviHistoryCollection(
        measurements: measurements,
        deviceId: deviceId,
      );

    } catch (e) {
      throw RuuviConnectionException('Failed to read history: $e');
    }
  }

  /// Parses a Ruuvi Log Response packet (11 bytes)
  Map<String, dynamic>? _parseRuuviLogResponse(Uint8List data) {
    if (data.length != 11) return null;

    try {
      final source = data[1];
      final type = data[2];

      if (type != 0x10) return null; // Not a log write response

      // Parse timestamp (4 bytes, big-endian)
      final timestamp = (data[3] << 24) | (data[4] << 16) | (data[5] << 8) | data[6];

      // Parse value (4 bytes, big-endian, signed)
      final rawValue = (data[7] << 24) | (data[8] << 16) | (data[9] << 8) | data[10];
      final value = rawValue > 0x7FFFFFFF ? rawValue - 0x100000000 : rawValue;

      // Check for end marker
      if (value == -1) {
        return {'isEndMarker': true};
      }

      // Convert based on source endpoint
      String sensorType;
      double convertedValue;

      switch (source) {
        case 0x30: // temperature endpoint
          sensorType = 'temperature';
          convertedValue = value * 0.01; // 0.01°C per LSB
          break;
        case 0x31: // humidity endpoint
          sensorType = 'humidity';
          convertedValue = value * 0.01; // 0.01% per LSB
          break;
        case 0x32: // pressure endpoint
          sensorType = 'pressure';
          convertedValue = value.toDouble() / 100.0; // 1 Pa per LSB -> hPa
          break;
        default:
          return null; // Unknown sensor type
      }

      return {
        'timestamp': timestamp,
        'sensorType': sensorType,
        'value': convertedValue,
        'isEndMarker': false,
      };

    } catch (e) {
      return null;
    }
  }
}
