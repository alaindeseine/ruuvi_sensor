import 'dart:io';

import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exceptions/ruuvi_exceptions.dart';

/// Checks that Bluetooth is available and on, and requests the runtime
/// permissions needed to scan and connect.
///
/// On Android 12+ this is `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` (no location:
/// the manifest is expected to declare `neverForLocation`). On older Android
/// versions these two report as granted, and flutter_blue_ultra requests the
/// location permission itself when scanning.
///
/// Throws [RuuviException] when Bluetooth is unsupported or off, or when a
/// permission is denied.
Future<void> ensureBluetoothReady() async {
  if (!await FlutterBlueUltra.isSupported) {
    throw const RuuviException('Bluetooth is not supported on this device');
  }

  if (Platform.isAndroid) {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final denied = results.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();
    if (denied.isNotEmpty) {
      throw RuuviException(
        'Bluetooth permissions denied: ${denied.join(', ')}',
      );
    }
  }

  final state = await FlutterBlueUltra.adapterState
      .where((s) => s != BluetoothAdapterState.unknown)
      .first
      .timeout(
        const Duration(seconds: 3),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
  if (state != BluetoothAdapterState.on) {
    throw const RuuviException('Bluetooth is turned off');
  }
}
