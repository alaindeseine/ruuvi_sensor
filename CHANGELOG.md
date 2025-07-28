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
