## 0.1.0+history-rewrite

* **MAJOR REWRITE**: Complete overhaul of historical data retrieval for firmware 3.31.1+
* **BREAKING CHANGE**: `getStoredData()` now uses Cut-RAWv2 format instead of old protocol
* **NEW**: Added `RuuviHistoryParser` class for Cut-RAWv2 format parsing
* **FIXED**: Corrected Nordic UART Service UUID assignments (TX/RX were swapped)
* **IMPROVED**: Proper command sending via TX characteristic (6E400002)
* **IMPROVED**: Proper data reception via RX characteristic (6E400003)
* **NEW**: Supports history commands 0x03, 0x05, and 0x80 with automatic fallback
* **NEW**: 10-byte entry parsing: timestamp + temperature + humidity + pressure
* **NEW**: Proper Cut-RAWv2 data validation and range checking
* **IMPROVED**: Enhanced debugging and logging throughout the process
* **COMPATIBLE**: Works with RuuviTag firmware 3.31.1+ (Cut-RAWv2 format)

## 0.0.9+device-info-fix

* **IMPROVED**: Better Device Information Service (180A) reading
* Correctly searches for characteristics using UUID contains() method
* Added `readDeviceInformationService()` method for comprehensive device info
* Reads serial number (2A25), firmware (2A26), hardware (2A27), manufacturer (2A29), model (2A24)
* Enhanced debugging with detailed logging of available services/characteristics
* Improved error handling and fallback mechanisms
* Better user feedback when Device Information Service is not available

## 0.0.8+serial-number

* **NEW FEATURE**: Added dedicated serial number reading capability
* Correctly reads serial number from Device Information Service (UUID 0x2A25)
* Added `readSerialNumber()` method to RuuviDevice class
* Fallback to device ID if Device Information Service not available
* Added "Serial" button in example app for quick serial number access
* Improved device identification for firmware 3.31.1 compatibility

## 0.0.7+device-info

* **NEW FEATURE**: Added device information reading capability
* Read firmware version, hardware version, manufacturer name from GATT
* Added `readDeviceInfo()` method to RuuviDevice class
* Added "Device Info" button in example app to test functionality
* Helps identify firmware version for protocol compatibility

## 0.0.6+scan-fix

* **CRITICAL FIX**: Fixed "Scan Once" continuing to scan indefinitely
* Properly manage scan state listeners and subscriptions
* Clean up resources on scan completion and errors
* Added `isActuallyScanning` method for debugging scan state
* Improved error handling in scan operations

## 0.0.5+ui-precision

* **UI FIX**: Temperature now displays with 2 decimal places in the user interface
* Updated example app, documentation, and all temperature displays for consistency
* Better temperature monitoring with precise real-time updates

## 0.0.4+precision

* Improved temperature display precision to 2 decimal places for better monitoring
* Enhanced debug logs for better temperature change visibility

## 0.0.3+fix

* **CRITICAL FIX**: Fixed UI not updating with real-time sensor data
* Now properly notifies listeners when existing device data changes
* Real-time temperature, humidity, and pressure updates now work correctly
* Continuous scanning mode now fully functional

## 0.0.2+debug

* Added comprehensive debug logging throughout the scanning process
* Updated Flutter Blue Plus dependency to 1.35.5
* Enhanced error reporting and troubleshooting capabilities
* Detailed traces for scan results, device detection, and data decoding
* Improved continuous scanning implementation

## 0.0.1

* Initial release of RuuviSensor package
* BLE scanning for RuuviTag devices with manufacturer ID filtering
* Real-time sensor data decoding from BLE advertisements (format 5/RAWv2)
* Device connection via Nordic UART Service (NUS)
* Historical data retrieval from connected devices
* Support for temperature, humidity, pressure, acceleration, and battery data
* Comprehensive error handling with specific exception types
* Complete example app demonstrating all features
* Full test coverage for data decoding and protocol handling
