# Quick Start Guide

## 🚀 For Your Test Project

### 1. Add the Package

In your `pubspec.yaml`:
```yaml
dependencies:
  ruuvi_sensor:
    path: ../path/to/ruuvi_sensor  # Adjust path as needed
  flutter_blue_plus: ^1.32.12
```

### 2. Add Permissions

**Android** - Create/edit `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Essential permissions for Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <!-- For older Android versions -->
    <uses-permission android:name="android.permission.BLUETOOTH" 
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" 
        android:maxSdkVersion="30" />
    
    <!-- BLE feature -->
    <uses-feature
        android:name="android.hardware.bluetooth_le"
        android:required="true" />

    <application
        android:label="your_app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

**iOS** - Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to scan for RuuviTag sensors</string>
```

### 3. Simple Test Code

Replace your `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuuviSensor Test',
      home: RuuviTestPage(),
    );
  }
}

class RuuviTestPage extends StatefulWidget {
  @override
  _RuuviTestPageState createState() => _RuuviTestPageState();
}

class _RuuviTestPageState extends State<RuuviTestPage> {
  final RuuviScanner _scanner = RuuviScanner();
  List<RuuviDevice> _devices = [];
  String _status = 'Ready';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scanner.devicesStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _checkSetup() async {
    setState(() => _status = 'Checking setup...');
    
    try {
      final result = await RuuviScanner.checkSetup();
      
      if (result.isReady) {
        setState(() => _status = 'Setup OK - Ready to scan!');
      } else {
        setState(() => _status = 'Setup needed:\n${result.recommendations.join('\n')}');
      }
    } catch (e) {
      setState(() => _status = 'Setup check failed: $e');
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
    });

    try {
      await _scanner.startScan(timeout: Duration(seconds: 30));
      setState(() => _status = 'Scan completed');
    } catch (e) {
      setState(() => _status = 'Scan failed:\n$e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RuuviSensor Test'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkSetup,
                    child: Text('Check Setup'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _startScan,
                    child: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Devices
            Text('Found ${_devices.length} RuuviTag(s):'),
            SizedBox(height: 8),
            
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final data = device.lastData;
                  
                  return Card(
                    child: ListTile(
                      title: Text(device.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Serial: ${device.serialNumber}'),
                          Text('RSSI: ${device.rssi} dBm'),
                          if (data != null) ...[
                            Text('Temp: ${data.temperature.toStringAsFixed(2)}°C'),
                            Text('Humidity: ${data.humidity.toStringAsFixed(1)}%'),
                            Text('Pressure: ${(data.pressure / 100).toStringAsFixed(0)} hPa'),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4. Test Steps

1. **Check Setup**: Tap "Check Setup" first
   - If OK: Proceed to scan
   - If not OK: Follow the displayed instructions

2. **Start Scan**: Tap "Start Scan"
   - Should find RuuviTag devices nearby
   - Shows real-time sensor data

### 5. Expected Results

✅ **Success**: You should see:
- "Setup OK - Ready to scan!"
- RuuviTag devices appearing in the list
- Real-time temperature, humidity, pressure data

❌ **If you get permission errors**:
- The package will show exactly what to add to your AndroidManifest.xml
- Copy-paste the provided permissions
- Restart the app

## 🔧 Troubleshooting

### "Setup needed" message
- Copy the exact permissions shown in the message
- Add them to your AndroidManifest.xml
- Clean and rebuild: `flutter clean && flutter run`

### No devices found
- Ensure RuuviTag is nearby and powered
- Check Bluetooth is enabled
- Try the "Check Setup" button first

### Still having issues?
- Check the full [PERMISSIONS.md](PERMISSIONS.md) guide
- Look at the complete [example](example/) app
- Ensure you're testing on a physical device (not simulator)

This should get you up and running quickly! 🚀
