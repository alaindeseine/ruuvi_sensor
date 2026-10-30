# ruuvi_sensor

Scan [RuuviTag](https://ruuvi.com/ruuvitag/) environmental sensors over Bluetooth Low Energy and download their logged history.

- **Live readings** from advertisements: temperature, humidity, pressure, acceleration, battery voltage, TX power, movement counter, measurement sequence and MAC address (data formats 3 / RAWv1 and 5 / RAWv2).
- **History download** over GATT (Nordic UART service): every value the tag logged, with a flag telling whether the transfer completed.
- **Device information**: model, firmware and hardware versions, serial number.
- Works with stock Ruuvi firmware and with firmwares that only log some sensors: missing values are `null`, never invented.

Built on [flutter_blue_ultra](https://pub.dev/packages/flutter_blue_ultra) (BSD-3-Clause).

## Platform support

| Platform | Status |
|---|---|
| Android | Supported and tested |
| iOS | Should work (the BLE layer supports it) but is not tested |

## Installation

```yaml
dependencies:
  ruuvi_sensor: ^1.1.0
```

### Android setup

`permission_handler` requires compiling against Android SDK 37. In `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 37
}
```

Declare the Bluetooth permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Android 12+ (API 31+): no location needed -->
    <uses-permission
        android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- Android 11 and below -->
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
    ...
</manifest>
```

The package requests the runtime permissions itself when you start a scan or connect to a tag, and throws a `RuuviException` if they are denied or Bluetooth is off.

### iOS setup

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to read RuuviTag sensors.</string>
```

## Usage

### Scan for tags

```dart
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

final scanner = RuuviBleScanner();

final subscription = scanner.devicesStream.listen((tags) {
  for (final tag in tags) {
    print('${tag.displayName}: ${tag.temperature} °C, '
        '${tag.humidity} %, ${tag.pressureHPa} hPa, ${tag.batteryVoltage} mV');
  }
});

await scanner.startScan(timeout: const Duration(seconds: 30));

// Later
await scanner.stopScan();
await subscription.cancel();
scanner.dispose();
```

`devicesStream` emits the full list of tags each time an advertisement is received, so several times per second when tags are nearby.

### Read the history

```dart
final reader = RuuviHistoryReader();

// Everything the tag kept (the last 30 days)
final history = await reader.getAllHistory(tag.deviceId);

// Or only what was logged since a given date
final recent = await reader.getHistory(
  tag.deviceId,
  startDate: DateTime.now().subtract(const Duration(days: 1)),
);

if (!history.isComplete) {
  // The transfer stopped early (tag out of range, timeout...).
  // `history.measurements` holds what was received so far.
}

for (final m in history.measurements) {
  print('${m.timestamp}: ${m.temperature} °C');
}

await reader.dispose();
```

Measurements are sorted oldest first. A value is `null` when the tag doesn't log that sensor: some firmwares only log temperature, in which case `getCompleteOnly()` returns an empty collection.

### Read device information

```dart
final info = await reader.getDeviceInformation(tag.deviceId);
print('${info.getModel()} ${info.getHardwareVersion()}, '
    'firmware ${info.getFirmwareVersion()}');
```

## Units

| Value | Scan (`RuuviBleScanResult`) | History (`RuuviHistoryMeasurement`) |
|---|---|---|
| Temperature | °C | °C |
| Humidity | % | % |
| Pressure | **Pa** (`pressure`), hPa (`pressureHPa`) | **hPa** |
| Acceleration | g | — |
| Battery | mV | — |

## Errors

Every method throws a subclass of `RuuviException`:

- `RuuviConnectionException`: the tag can't be reached or the connection failed.
- `RuuviDataException`: the tag doesn't expose the log service (firmware without GATT history).
- `RuuviException`: Bluetooth unavailable or turned off, permission denied, scan failure.

Operations on the same tag are queued: calling `getHistory()` while another read of that tag is running waits for it to finish.

## Troubleshooting

- **No tag found**: make sure Bluetooth is on, the permissions are granted and the tag is within range. BLE does not work on emulators: use a physical device.
- **History is empty or incomplete**: stay close to the tag during the transfer, and check `isComplete`. Tags running a firmware without GATT support (for example the stock "longlife" build) have no history: `getHistory()` throws `RuuviConnectionException` (tag not connectable) or `RuuviDataException` (no log service).

## License

MIT, see [LICENSE](LICENSE).
