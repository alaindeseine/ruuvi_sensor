## 1.0.4+fixed-timestamp-range

* **FIXED**: Use 30-day old timestamp instead of epoch 0 for complete history retrieval
* **FIXED**: RuuviTag now responds correctly when requesting all available data
* **IMPROVED**: Better timestamp range handling for getAllHistory() method
* **COMPATIBLE**: Works with RuuviTag firmware timestamp validation

## 1.0.3+fixed-history-retrieval

* **FIXED**: History retrieval now gets ALL available data instead of only "new" data
* **IMPROVED**: Added `getAllHistory()` convenience method to retrieve complete history
* **FIXED**: Corrected startTime parameter - use very old timestamp to get all data
* **IMPROVED**: Better documentation explaining startDate=null behavior
* **COMPATIBLE**: Matches Ruuvi Station behavior for complete history retrieval

## 1.0.2+fixed-permissions

* **FIXED**: Added proper BLE permissions handling for flutter_reactive_ble
* **NEW**: Automatic permission requests for Location, Bluetooth Scan, and Bluetooth Connect
* **IMPROVED**: Better error messages when permissions are missing
* **COMPATIBLE**: Works with Android 12+ permission requirements

## 1.0.1+fixed-parsing

* **FIXED**: Corrected manufacturer data parsing for RAWv1 and RAWv2 formats
* **FIXED**: Proper byte indexing after manufacturer ID extraction
* **NEW**: Data validation to reject aberrant sensor values
* **IMPROVED**: Updated flutter_reactive_ble to version 5.4.0
* **IMPROVED**: Better temperature, humidity, and pressure range validation

## 1.0.0+reactive-ble-only

* **BREAKING CHANGE**: Complete removal of flutter_blue_plus dependency
* **BREAKING CHANGE**: Removed old RuuviScanner, RuuviDevice, RuuviLogReader classes
* **NEW**: Clean API with only RuuviBleScanner and RuuviHistoryReader
* **NEW**: RuuviTagInformation model with device details and serial number detection
* **NEW**: RuuviHistoryMeasurement and RuuviHistoryCollection models
* **NEW**: Simplified example app with dual-column interface (devices | history)
* **IMPROVED**: Single BLE backend (flutter_reactive_ble) for consistency
* **IMPROVED**: Better separation between scanning and history retrieval

## 0.2.0+dual-ble-system

* **NEW**: Added RuuviHistoryReader class using flutter_reactive_ble
* **NEW**: Added RuuviBleScanner for device discovery with flutter_reactive_ble
* **NEW**: RuuviTagInformation model with device metadata
* **NEW**: RuuviHistoryMeasurement model with sensor data and utilities
* **NEW**: Dual BLE system support (flutter_blue_plus + flutter_reactive_ble)
* **NEW**: Enhanced example app with both old and new system testing
* **IMPROVED**: Better device information reading (serial number, firmware, etc.)
* **IMPROVED**: Complete history retrieval with proper Ruuvi Log Response parsing

## 0.1.0+history-rewrite (Legacy)

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
