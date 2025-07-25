# RuuviSensor Example App

This example demonstrates how to use the `ruuvi_sensor` package to scan for RuuviTag devices, connect to them, and retrieve historical sensor data.

## Features

- **Scan for RuuviTag devices**: Discover nearby RuuviTag sensors via Bluetooth Low Energy
- **Real-time sensor data**: View current temperature, humidity, and pressure readings
- **Device connection**: Connect to individual RuuviTag devices
- **Historical data retrieval**: Download stored sensor measurements from the device
- **Device details**: View comprehensive information about each sensor

## Prerequisites

Before running this example, make sure you have:

1. **Flutter SDK** installed (version 3.8.1 or higher)
2. **Physical device** with Bluetooth Low Energy support (BLE scanning doesn't work on simulators)
3. **RuuviTag sensors** to test with
4. **Permissions** configured for your platform

### Android Permissions

Add these permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Permissions

Add this to your `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to scan for RuuviTag sensors</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for Bluetooth scanning</string>
```

## Running the Example

1. Navigate to the example directory:
   ```bash
   cd example
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run on a physical device:
   ```bash
   flutter run
   ```

## How to Use

1. **Grant Permissions**: When you first run the app, it will request necessary Bluetooth and location permissions.

2. **Start Scanning**: Tap "Start Scan" to begin searching for RuuviTag devices. The app will scan for 30 seconds.

3. **View Devices**: Discovered RuuviTag devices will appear in a list showing:
   - Device name and signal strength (RSSI)
   - Serial number (MAC address)
   - Current sensor readings (temperature, humidity, pressure)

4. **View Details**: Tap "View Details" on any device to see more information and access additional features.

5. **Connect to Device**: In the details page, tap "Connect" to establish a Bluetooth connection with the RuuviTag.

6. **Get Historical Data**: Once connected, tap "Get History" to download stored sensor measurements from the device.

## Code Structure

The example consists of three main screens:

- **RuuviScannerPage**: Main screen for scanning and listing devices
- **RuuviDeviceCard**: Widget displaying basic device information
- **RuuviDeviceDetailsPage**: Detailed view with connection and historical data features

## Key Code Examples

### Scanning for Devices

```dart
final RuuviScanner scanner = RuuviScanner();

// Listen for discovered devices
scanner.devicesStream.listen((devices) {
  // Update UI with discovered devices
});

// Start scanning
await scanner.startScan(timeout: Duration(seconds: 30));
```

### Connecting to a Device

```dart
final RuuviDevice device = // ... from scan results

// Connect to the device
await device.connect();

// Check connection status
bool isConnected = device.isConnected;
```

### Retrieving Historical Data

```dart
// Get stored data (requires connection)
final RuuviMeasurement measurement = await device.getStoredData(
  startTime: DateTime.now().subtract(Duration(days: 7)),
);

// Access the measurements
for (final data in measurement.measurements) {
  print('Temperature: ${data.temperature}°C');
  print('Humidity: ${data.humidity}%');
  print('Pressure: ${data.pressure} Pa');
  print('Timestamp: ${data.timestamp}');
}
```

## Troubleshooting

### No devices found
- Ensure your RuuviTag is powered on and in range
- Check that Bluetooth is enabled on your device
- Verify location permissions are granted (required for BLE scanning)

### Connection fails
- Make sure the device is not connected to another app
- Try moving closer to the RuuviTag
- Restart Bluetooth on your device

### Historical data retrieval fails
- Ensure you're connected to the device first
- Check that the RuuviTag has stored data (it needs to run for some time)
- Verify the device supports historical data (firmware version 3.x or higher)

## Learn More

For more information about the RuuviSensor package, see the main [README](../README.md) and [API documentation](../doc/api/).
