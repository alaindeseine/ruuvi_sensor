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
