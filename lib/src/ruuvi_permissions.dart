import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'exceptions/ruuvi_exceptions.dart';

/// Utility class for managing Ruuvi sensor permissions
class RuuviPermissions {
  
  /// Checks if all required permissions are available for BLE scanning
  /// 
  /// Returns a detailed status with missing permissions and solutions
  static Future<PermissionCheckResult> checkPermissions() async {
    final missingPermissions = <String>[];
    final recommendations = <String>[];
    
    try {
      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        return PermissionCheckResult(
          isReady: false,
          missingPermissions: ['Bluetooth not supported'],
          recommendations: ['This device does not support Bluetooth Low Energy'],
        );
      }
      
      // Check if Bluetooth is enabled
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        missingPermissions.add('Bluetooth disabled');
        recommendations.add('Please enable Bluetooth in device settings');
      }
      
    } catch (e) {
      // If we can't check Bluetooth status, likely a permission issue
      if (Platform.isAndroid) {
        missingPermissions.add('Bluetooth permissions');
        recommendations.addAll(_getAndroidPermissionInstructions());
      } else if (Platform.isIOS) {
        missingPermissions.add('Bluetooth permissions');
        recommendations.addAll(_getIOSPermissionInstructions());
      }
    }
    
    return PermissionCheckResult(
      isReady: missingPermissions.isEmpty,
      missingPermissions: missingPermissions,
      recommendations: recommendations,
    );
  }
  
  /// Gets Android-specific permission setup instructions
  static List<String> _getAndroidPermissionInstructions() {
    return [
      'Add these permissions to android/app/src/main/AndroidManifest.xml:',
      '',
      '<!-- For Android 12+ (API 31+) -->',
      '<uses-permission android:name="android.permission.BLUETOOTH_SCAN"',
      '    android:usesPermissionFlags="neverForLocation" />',
      '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />',
      '',
      '<!-- For older Android versions -->',
      '<uses-permission android:name="android.permission.BLUETOOTH"',
      '    android:maxSdkVersion="30" />',
      '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"',
      '    android:maxSdkVersion="30" />',
      '',
      '<!-- Location (if neverForLocation flag not used) -->',
      '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
      '',
      'Also ensure compileSdk and targetSdk are 31+ in android/app/build.gradle',
    ];
  }
  
  /// Gets iOS-specific permission setup instructions
  static List<String> _getIOSPermissionInstructions() {
    return [
      'Add this to ios/Runner/Info.plist:',
      '',
      '<key>NSBluetoothAlwaysUsageDescription</key>',
      '<string>This app needs Bluetooth access to scan for RuuviTag sensors</string>',
      '',
      'If using location-based scanning, also add:',
      '<key>NSLocationWhenInUseUsageDescription</key>',
      '<string>This app needs location access for Bluetooth scanning</string>',
    ];
  }
  
  /// Provides a user-friendly error message with setup instructions
  static RuuviException createPermissionException(PermissionCheckResult result) {
    final buffer = StringBuffer();
    buffer.writeln('RuuviSensor setup required:');
    buffer.writeln();
    
    if (result.missingPermissions.isNotEmpty) {
      buffer.writeln('Missing: ${result.missingPermissions.join(', ')}');
      buffer.writeln();
    }
    
    if (result.recommendations.isNotEmpty) {
      buffer.writeln('Setup instructions:');
      for (final recommendation in result.recommendations) {
        buffer.writeln(recommendation);
      }
    }
    
    return RuuviException(buffer.toString());
  }
}

/// Result of permission check with detailed information
class PermissionCheckResult {
  final bool isReady;
  final List<String> missingPermissions;
  final List<String> recommendations;
  
  const PermissionCheckResult({
    required this.isReady,
    required this.missingPermissions,
    required this.recommendations,
  });
  
  @override
  String toString() {
    return 'PermissionCheckResult(isReady: $isReady, missing: $missingPermissions)';
  }
}
