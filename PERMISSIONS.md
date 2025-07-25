# RuuviSensor Permissions Setup

This guide helps you configure the necessary permissions for the RuuviSensor package to work properly on Android and iOS.

## 🤖 Android Setup

### Required Permissions

Add these permissions to your `android/app/src/main/AndroidManifest.xml` file:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Bluetooth permissions for Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    
    <!-- Bluetooth permissions for older Android versions -->
    <uses-permission android:name="android.permission.BLUETOOTH" 
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" 
        android:maxSdkVersion="30" />
    
    <!-- Location permissions (only if neverForLocation flag is not used) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Bluetooth LE feature -->
    <uses-feature
        android:name="android.hardware.bluetooth_le"
        android:required="true" />

    <application>
        <!-- Your app configuration -->
    </application>
</manifest>
```

### Build Configuration

Ensure your `android/app/build.gradle` has the correct SDK versions:

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### Key Points for Android

1. **Android 12+ (API 31+)**: Uses new runtime permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`)
2. **`neverForLocation` flag**: Allows BLE scanning without location permission
3. **Older Android**: Falls back to legacy permissions (`BLUETOOTH`, `BLUETOOTH_ADMIN`)

## 🍎 iOS Setup

### Required Permissions

Add these entries to your `ios/Runner/Info.plist` file:

```xml
<dict>
    <!-- Bluetooth usage description -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This app needs Bluetooth access to scan for RuuviTag sensors</string>
    
    <!-- Location usage (if needed for scanning) -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app needs location access for Bluetooth scanning</string>
    
    <!-- Your other app configuration -->
</dict>
```

### Key Points for iOS

1. **Usage descriptions are mandatory**: iOS will reject apps without proper descriptions
2. **Location permission**: May be required depending on iOS version and scanning method
3. **Background scanning**: Requires additional configuration if needed

## 🔧 Using the Package's Permission Helper

The RuuviSensor package includes a built-in permission checker:

```dart
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

// Check if setup is complete before scanning
final setupResult = await RuuviScanner.checkSetup();

if (!setupResult.isReady) {
  // Show setup instructions to user
  print('Setup required:');
  for (final instruction in setupResult.recommendations) {
    print(instruction);
  }
  
  // Or throw exception with detailed instructions
  throw RuuviPermissions.createPermissionException(setupResult);
}

// Proceed with scanning
final scanner = RuuviScanner();
await scanner.startScan();
```

## 🚨 Common Issues and Solutions

### "BLUETOOTH_SCAN permission denied"

**Solution**: Add the Android 12+ permissions to your AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
    android:usesPermissionFlags="neverForLocation" />
```

### "Location permission required"

**Solutions**:
1. **Preferred**: Use `neverForLocation` flag (Android 12+)
2. **Alternative**: Request location permission at runtime
3. **Legacy**: Add location permissions to manifest

### "Bluetooth not supported"

**Check**:
1. Device has Bluetooth LE hardware
2. Bluetooth is enabled in device settings
3. App has proper permissions

### iOS app rejected

**Solution**: Ensure usage descriptions are clear and accurate:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app scans for RuuviTag environmental sensors to read temperature, humidity, and pressure data</string>
```

## 📱 Runtime Permission Handling

For better user experience, handle permissions gracefully:

```dart
try {
  await scanner.startScan();
} on RuuviException catch (e) {
  if (e.message.contains('permission') || e.message.contains('setup')) {
    // Show user-friendly setup dialog
    showSetupDialog(context, e.message);
  } else {
    // Handle other errors
    showErrorDialog(context, e.message);
  }
}
```

## 🔍 Testing Permissions

1. **Clean install**: Test on fresh app installation
2. **Permission denial**: Test when user denies permissions
3. **Settings change**: Test when user changes permissions in device settings
4. **Different Android versions**: Test on various API levels

## 📚 Additional Resources

- [Android Bluetooth permissions guide](https://developer.android.com/guide/topics/connectivity/bluetooth/permissions)
- [iOS Core Bluetooth guide](https://developer.apple.com/documentation/corebluetooth)
- [Flutter Blue Plus documentation](https://pub.dev/packages/flutter_blue_plus)

## 💡 Pro Tips

1. **Check setup early**: Call `RuuviScanner.checkSetup()` on app start
2. **Graceful degradation**: Provide alternative features if BLE unavailable
3. **Clear messaging**: Explain why permissions are needed
4. **Test thoroughly**: Different devices and OS versions behave differently
