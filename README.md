# RuuviSensor

A Flutter package for interfacing with Ruuvi environmental sensors via Bluetooth Low Energy (BLE). This package allows you to scan for RuuviTag devices, read real-time sensor data from advertisements, connect to devices, and retrieve historical sensor measurements.

## Features

- **🔍 Device Discovery**: Scan for nearby RuuviTag sensors using BLE
- **📊 Real-time Data**: Read current temperature, humidity, pressure, and other sensor values from BLE advertisements
- **🔗 Device Connection**: Connect to RuuviTag devices via Nordic UART Service (NUS)
- **📈 Historical Data**: Retrieve stored sensor measurements from connected devices
- **⚡ Format Support**: Full support for Ruuvi data format 5 (RAWv2)
- **🛡️ Error Handling**: Comprehensive exception handling for connection and data issues
- **📱 Cross-platform**: Works on both Android and iOS

## Supported Sensors

This package supports RuuviTag sensors with firmware version 3.x or higher that implement:
- Ruuvi data format 5 (RAWv2) for advertisements
- Nordic UART Service (NUS) for device communication
- Historical data logging capabilities

## Getting Started

### Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  ruuvi_sensor: ^0.0.1
  flutter_blue_plus: ^1.32.12  # Required peer dependency
```

### Permissions

**⚠️ Important**: The package will automatically detect missing permissions and provide detailed setup instructions.

For complete permission setup instructions, see [PERMISSIONS.md](PERMISSIONS.md).

#### Quick Setup

**Android** - Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- For Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- For older versions -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

**iOS** - Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to scan for RuuviTag sensors</string>
```

#### Permission Helper

The package includes a built-in permission checker:

```dart
// Check setup before scanning
final setupResult = await RuuviScanner.checkSetup();
if (!setupResult.isReady) {
  // Show setup instructions
  print(setupResult.recommendations.join('\n'));
}
```

## Usage

### Basic Scanning

```dart
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

// Create a scanner instance
final scanner = RuuviScanner();

// Listen for discovered devices
scanner.devicesStream.listen((devices) {
  for (final device in devices) {
    print('Found: ${device.name} (${device.serialNumber})');

    // Access real-time sensor data
    final data = device.lastData;
    if (data != null) {
      print('Temperature: ${data.temperature}°C');
      print('Humidity: ${data.humidity}%');
      print('Pressure: ${data.pressure} Pa');
    }
  }
});

// Start scanning
await scanner.startScan(timeout: Duration(seconds: 30));

// Stop scanning
await scanner.stopScan();

// Clean up
scanner.dispose();
```

### Connecting to a Device

```dart
// Get a device from scan results
final device = devices.first;

try {
  // Connect to the device
  await device.connect();
  print('Connected to ${device.name}');

  // Check connection status
  if (device.isConnected) {
    // Device is ready for communication
  }

} catch (e) {
  print('Connection failed: $e');
}
```

### Retrieving Historical Data

```dart
try {
  // Get stored data from the last 7 days
  final measurement = await device.getStoredData(
    startTime: DateTime.now().subtract(Duration(days: 7)),
    timeout: Duration(minutes: 5),
  );

  print('Retrieved ${measurement.totalCount} measurements');
  print('Time range: ${measurement.startTime} to ${measurement.endTime}');

  // Process individual measurements
  for (final data in measurement.measurements) {
    print('${data.timestamp}: ${data.temperature}°C, ${data.humidity}%, ${data.pressure} Pa');
  }

} catch (e) {
  print('Failed to get historical data: $e');
} finally {
  // Always disconnect when done
  await device.disconnect();
}
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

class RuuviExample extends StatefulWidget {
  @override
  _RuuviExampleState createState() => _RuuviExampleState();
}

class _RuuviExampleState extends State<RuuviExample> {
  final RuuviScanner _scanner = RuuviScanner();
  List<RuuviDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _scanner.devicesStream.listen((devices) {
      setState(() => _devices = devices);
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      await _scanner.startScan(timeout: Duration(seconds: 30));
    } catch (e) {
      print('Scan failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RuuviTag Scanner')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _startScan,
            child: Text('Start Scan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                final data = device.lastData;

                return ListTile(
                  title: Text(device.name),
                  subtitle: data != null
                      ? Text('${data.temperature.toStringAsFixed(1)}°C, '
                             '${data.humidity.toStringAsFixed(1)}%, '
                             '${(data.pressure / 100).toStringAsFixed(0)} hPa')
                      : Text('No data'),
                  trailing: Text('${device.rssi} dBm'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## API Reference

### RuuviScanner

Main class for discovering RuuviTag devices.

#### Methods
- `startScan({Duration? timeout})` - Start scanning for devices
- `stopScan()` - Stop the current scan
- `dispose()` - Clean up resources

#### Properties
- `devicesStream` - Stream of discovered devices
- `discoveredDevices` - List of currently discovered devices
- `isScanning` - Whether currently scanning

### RuuviDevice

Represents a discovered RuuviTag device.

#### Methods
- `connect()` - Connect to the device
- `disconnect()` - Disconnect from the device
- `getStoredData({DateTime? startTime, Duration timeout})` - Retrieve historical data

#### Properties
- `device` - Underlying BluetoothDevice
- `serialNumber` - Device serial number (MAC address)
- `name` - Device display name
- `rssi` - Signal strength
- `lastData` - Most recent sensor data
- `isConnected` - Connection status

### RuuviData

Contains sensor measurement data.

#### Properties
- `deviceId` - Device identifier
- `serialNumber` - Device serial number
- `temperature` - Temperature in Celsius
- `humidity` - Relative humidity percentage
- `pressure` - Atmospheric pressure in Pascals
- `timestamp` - Measurement timestamp
- `batteryVoltage` - Battery voltage in millivolts
- `rssi` - Signal strength
- `accelerationX/Y/Z` - Acceleration values in G
- `txPower` - Transmission power in dBm
- `movementCounter` - Movement detection counter
- `sequenceNumber` - Measurement sequence number

### RuuviMeasurement

Collection of historical measurements.

#### Properties
- `measurements` - List of RuuviData objects
- `startTime` - Earliest measurement timestamp
- `endTime` - Latest measurement timestamp
- `totalCount` - Total number of measurements

## Error Handling

The package provides specific exception types:

- `RuuviException` - Base exception class
- `RuuviConnectionException` - Connection-related errors
- `RuuviDataException` - Data parsing or retrieval errors

```dart
try {
  await device.connect();
} on RuuviConnectionException catch (e) {
  print('Connection error: $e');
} on RuuviException catch (e) {
  print('General Ruuvi error: $e');
}
```

## Example App

See the [example](example/) directory for a complete Flutter app demonstrating all package features.

## Limitations

- Only supports Ruuvi data format 5 (RAWv2)
- Historical data retrieval requires firmware 3.x or higher
- BLE scanning requires location permissions on Android
- Physical device required (BLE doesn't work on simulators)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Additional Information

- **Issues**: Report bugs and feature requests on [GitHub Issues](https://github.com/alaindeseine/ruuvi_sensor/issues)
- **Documentation**: [API Documentation](https://pub.dev/documentation/ruuvi_sensor/latest/)
- **RuuviTag**: Learn more about RuuviTag sensors at [ruuvi.com](https://ruuvi.com)
- **Protocol**: Based on [Ruuvi sensor protocols](https://docs.ruuvi.com)
