import 'dart:async';

import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';

import 'exceptions/ruuvi_exceptions.dart';
import 'models/ruuvi_history_measurement.dart';
import 'models/ruuvi_tag_information.dart';
import 'ruuvi_log_parser.dart';
import 'ruuvi_permissions.dart';

/// Reads device information and logged history from a RuuviTag over GATT.
///
/// Only one operation runs at a time per tag: a call made while another one
/// is in progress on the same tag waits for it to finish.
class RuuviHistoryReader {
  // Nordic UART Service. Characteristic names follow the tag's point of view:
  // we write commands to RX and receive log packets as TX notifications.
  static final Guid _nusServiceUuid = Guid(
    '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  );
  static final Guid _rxCharacteristicUuid = Guid(
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  );
  static final Guid _txCharacteristicUuid = Guid(
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  );
  static final Guid _deviceInfoServiceUuid = Guid('180a');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  /// A transfer is considered over when no packet arrived for this long.
  static const Duration _silenceTimeout = Duration(seconds: 10);

  /// Firmware rejects a start time of 0 (epoch), so "all history" means
  /// this far back.
  static const Duration _allHistoryRange = Duration(days: 30);

  final Map<String, Future<void>> _pending = {};
  final Set<String> _connected = {};

  /// Reads device information from a RuuviTag
  ///
  /// Returns [RuuviTagInformation] with device details. Fields the tag
  /// doesn't expose are `null`; the identifier falls back to [deviceId].
  /// Throws [RuuviConnectionException] if connection fails
  Future<RuuviTagInformation> getDeviceInformation(String deviceId) {
    return _exclusive(deviceId, () async {
      final device = await _connect(deviceId);
      try {
        final services = await device.discoverServices();
        final info = services
            .where((s) => s.uuid == _deviceInfoServiceUuid)
            .firstOrNull;

        final values = <String, String>{};
        for (final c in info?.characteristics ?? <BluetoothCharacteristic>[]) {
          try {
            values[c.uuid.str.toLowerCase()] = String.fromCharCodes(
              await c.read(),
            ).trim();
          } catch (_) {
            // Unreadable characteristic: leave the field empty.
          }
        }

        return RuuviTagInformation(
          identifier: values['2a25'] ?? deviceId,
          macAddress: deviceId,
          manufacturer: values['2a29'],
          model: values['2a24'],
          firmwareVersion: values['2a26'],
          hardwareVersion: values['2a27'],
        );
      } on RuuviException {
        rethrow;
      } catch (e) {
        throw RuuviConnectionException('Failed to read device information: $e');
      } finally {
        await _disconnect(device);
      }
    });
  }

  /// Reads historical data from a RuuviTag
  ///
  /// [deviceId] MAC address of the RuuviTag
  /// [startDate] only values logged after this date. When `null`, reads the
  /// last 30 days, i.e. everything a tag normally keeps (the firmware rejects
  /// an epoch start).
  /// [endDate] optional end date (defaults to now)
  /// [timeout] upper bound for the whole transfer.
  ///
  /// Returns [RuuviHistoryCollection] sorted oldest first. Check
  /// [RuuviHistoryCollection.isComplete]: when the transfer stops early, the
  /// values received so far are returned with `isComplete == false`.
  ///
  /// Throws [RuuviConnectionException] if the tag can't be reached or the
  /// connection fails before the transfer starts.
  /// Throws [RuuviDataException] if the tag doesn't expose the log service
  /// (firmware without GATT logging).
  Future<RuuviHistoryCollection> getHistory(
    String deviceId, {
    DateTime? startDate,
    DateTime? endDate,
    Duration timeout = const Duration(minutes: 5),
  }) {
    return _exclusive(deviceId, () async {
      final now = DateTime.now();
      final end = endDate ?? now;
      final start = startDate ?? now.subtract(_allHistoryRange);

      final device = await _connect(deviceId);
      StreamSubscription<List<int>>? valueSubscription;
      StreamSubscription<BluetoothConnectionState>? stateSubscription;
      Timer? silenceTimer;
      try {
        final services = await device.discoverServices();
        final nus = services
            .where((s) => s.uuid == _nusServiceUuid)
            .firstOrNull;
        final rx = nus?.characteristics
            .where((c) => c.uuid == _rxCharacteristicUuid)
            .firstOrNull;
        final tx = nus?.characteristics
            .where((c) => c.uuid == _txCharacteristicUuid)
            .firstOrNull;
        if (rx == null || tx == null) {
          throw const RuuviDataException(
            'Log service not found: the tag firmware does not support history',
          );
        }

        final groups = <int, Map<String, double>>{};
        final done = Completer<bool>(); // true = end-of-log received

        void finish(bool complete) {
          if (!done.isCompleted) done.complete(complete);
        }

        void armSilenceTimer() {
          silenceTimer?.cancel();
          silenceTimer = Timer(_silenceTimeout, () => finish(false));
        }

        valueSubscription = tx.onValueReceived.listen((data) {
          armSilenceTimer();
          switch (parseRuuviLogPacket(data)) {
            case RuuviLogValue(
              :final timestamp,
              :final sensorType,
              :final value,
            ):
              (groups[timestamp] ??= {})[sensorType] = value;
            case RuuviLogEnd():
              finish(true);
            case RuuviLogAborted():
              finish(false);
            case null:
              break;
          }
        }, onError: (Object _) => finish(false));

        stateSubscription = device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) finish(false);
        });

        await tx.setNotifyValue(true);
        armSilenceTimer();
        await rx.write(
          _buildLogReadCommand(end, start),
          withoutResponse: rx.properties.writeWithoutResponse,
        );

        final complete = await done.future.timeout(
          timeout,
          onTimeout: () => false,
        );

        final measurements = [
          for (final entry in groups.entries)
            RuuviHistoryMeasurement(
              timestamp: DateTime.fromMillisecondsSinceEpoch(entry.key * 1000),
              temperature: entry.value['temperature'],
              humidity: entry.value['humidity'],
              pressure: entry.value['pressure'],
            ),
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return RuuviHistoryCollection(
          measurements: measurements,
          deviceId: deviceId,
          isComplete: complete,
        );
      } on RuuviException {
        rethrow;
      } catch (e) {
        throw RuuviConnectionException('Failed to read history: $e');
      } finally {
        silenceTimer?.cancel();
        await valueSubscription?.cancel();
        await stateSubscription?.cancel();
        await _disconnect(device);
      }
    });
  }

  /// Reads ALL available historical data from a RuuviTag
  ///
  /// Same as [getHistory] with `startDate: null`.
  Future<RuuviHistoryCollection> getAllHistory(
    String deviceId, {
    DateTime? endDate,
    Duration timeout = const Duration(minutes: 5),
  }) {
    return getHistory(deviceId, endDate: endDate, timeout: timeout);
  }

  /// Former test method; the firmware rejects an epoch start time.
  @Deprecated('Use getAllHistory() instead. Will be removed in 2.0.0.')
  Future<RuuviHistoryCollection> getHistoryFromEpoch(
    String deviceId, {
    DateTime? endDate,
  }) {
    return getAllHistory(deviceId, endDate: endDate);
  }

  /// Disconnects from every tag this reader is connected to.
  Future<void> dispose() async {
    for (final id in _connected.toList()) {
      await _disconnect(BluetoothDevice.fromId(id));
    }
  }

  /// `[0x3A, 0x3A, 0x11, now (u32 BE), start (u32 BE)]`, Unix seconds.
  static List<int> _buildLogReadCommand(DateTime now, DateTime start) {
    List<int> u32(DateTime d) {
      final s = d.millisecondsSinceEpoch ~/ 1000;
      return [(s >> 24) & 0xFF, (s >> 16) & 0xFF, (s >> 8) & 0xFF, s & 0xFF];
    }

    return [0x3A, 0x3A, 0x11, ...u32(now), ...u32(start)];
  }

  Future<BluetoothDevice> _connect(String deviceId) async {
    await ensureBluetoothReady();
    final device = BluetoothDevice.fromId(deviceId);
    try {
      await device.connect(timeout: _connectionTimeout);
      _connected.add(deviceId);
      return device;
    } catch (e) {
      await _disconnect(device);
      throw RuuviConnectionException(
        'Failed to connect to device $deviceId: $e',
      );
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    _connected.remove(device.remoteId.str);
    try {
      await device.disconnect();
    } catch (_) {
      // Already disconnected.
    }
  }

  /// Runs [action] once every earlier operation on [deviceId] has finished.
  Future<T> _exclusive<T>(String deviceId, Future<T> Function() action) {
    final previous = _pending[deviceId] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>((_) {}, onError: (_) {});
    _pending[deviceId] = tail;
    tail.whenComplete(() {
      if (identical(_pending[deviceId], tail)) _pending.remove(deviceId);
    });
    return result;
  }
}
