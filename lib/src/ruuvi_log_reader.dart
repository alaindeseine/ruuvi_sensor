import 'dart:async';
import 'dart:typed_data';
import 'models/ruuvi_data.dart';
import 'models/ruuvi_measurement.dart';
import 'exceptions/ruuvi_exceptions.dart';

/// Handles reading logged data from RuuviTag via Nordic UART Service
class RuuviLogReader {
  // Data endpoints from Ruuvi documentation
  static const int _temperatureEndpoint = 0x30;
  static const int _humidityEndpoint = 0x31;
  static const int _pressureEndpoint = 0x32;
  static const int _environmentalEndpoint = 0x3A; // All environmental data
  
  // Command types
  static const int _logReadCommand = 0x11;
  static const int _logWriteResponse = 0x10;
  static const int _errorResponse = 0xF0;
  
  final Function(Uint8List) _sendCommand;
  final Stream<Uint8List> _responseStream;
  
  RuuviLogReader(this._sendCommand, this._responseStream);
  
  /// Reads all environmental data from the device
  /// 
  /// [startTime] earliest timestamp to retrieve (seconds since Unix epoch)
  /// [endTime] current time (seconds since Unix epoch)
  /// [deviceId] device identifier for the returned data
  /// 
  /// Returns [RuuviMeasurement] containing all retrieved data
  /// Throws [RuuviDataException] if read fails or times out
  Future<RuuviMeasurement> readEnvironmentalData({
    required int startTime,
    required int endTime,
    required String deviceId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final measurements = <RuuviData>[];
    final completer = Completer<RuuviMeasurement>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;
    
    try {
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            RuuviDataException('Log read timeout after ${timeout.inMinutes} minutes'),
          );
        }
      });
      
      // Listen for responses
      subscription = _responseStream.listen(
        (data) => _handleLogResponse(data, measurements, deviceId, completer),
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(RuuviDataException('Response stream error: $error'));
          }
        },
      );
      
      // Send log read command for all environmental data
      final command = _createLogReadCommand(
        destination: _environmentalEndpoint,
        source: _environmentalEndpoint,
        currentTime: endTime,
        startTime: startTime,
      );
      
      await _sendCommand(command);
      
      // Wait for completion
      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      await subscription?.cancel();
    }
  }
  
  /// Creates a log read command according to Ruuvi protocol
  Uint8List _createLogReadCommand({
    required int destination,
    required int source,
    required int currentTime,
    required int startTime,
  }) {
    final command = Uint8List(11);
    
    // Header (3 bytes)
    command[0] = destination;
    command[1] = source;
    command[2] = _logReadCommand;
    
    // Current time (4 bytes, big-endian)
    command[3] = (currentTime >> 24) & 0xFF;
    command[4] = (currentTime >> 16) & 0xFF;
    command[5] = (currentTime >> 8) & 0xFF;
    command[6] = currentTime & 0xFF;
    
    // Start time (4 bytes, big-endian)
    command[7] = (startTime >> 24) & 0xFF;
    command[8] = (startTime >> 16) & 0xFF;
    command[9] = (startTime >> 8) & 0xFF;
    command[10] = startTime & 0xFF;
    
    return command;
  }
  
  /// Handles incoming log response data
  void _handleLogResponse(
    Uint8List data,
    List<RuuviData> measurements,
    String deviceId,
    Completer<RuuviMeasurement> completer,
  ) {
    if (data.length < 3) {
      return; // Invalid response
    }
    
    final destination = data[0];
    final source = data[1];
    final type = data[2];
    
    // Check for error response
    if (type == _errorResponse) {
      if (!completer.isCompleted) {
        completer.completeError(
          RuuviDataException('Device reported error during log read'),
        );
      }
      return;
    }
    
    // Check for log write response
    if (type != _logWriteResponse || data.length < 11) {
      return; // Not a log entry or invalid length
    }
    
    // Check for end of data marker (all 0xFF)
    if (data.every((byte) => byte == 0xFF)) {
      // End of log data
      if (!completer.isCompleted) {
        final startTime = measurements.isNotEmpty 
            ? measurements.first.timestamp 
            : DateTime.now();
        final endTime = measurements.isNotEmpty 
            ? measurements.last.timestamp 
            : DateTime.now();
            
        completer.complete(RuuviMeasurement(
          measurements: measurements,
          startTime: startTime,
          endTime: endTime,
          totalCount: measurements.length,
        ));
      }
      return;
    }
    
    // Parse timestamp (4 bytes, big-endian)
    final timestamp = (data[3] << 24) | (data[4] << 16) | (data[5] << 8) | data[6];
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    
    // Parse value (4 bytes, big-endian, signed)
    final rawValue = (data[7] << 24) | (data[8] << 16) | (data[9] << 8) | data[10];
    final value = rawValue > 0x7FFFFFFF ? rawValue - 0x100000000 : rawValue;
    
    // Convert based on source endpoint
    RuuviData? ruuviData;
    switch (source) {
      case _temperatureEndpoint:
        ruuviData = RuuviData(
          deviceId: deviceId,
          temperature: value * 0.01, // 0.01°C per LSB
          humidity: double.nan,
          pressure: double.nan,
          timestamp: dateTime,
        );
        break;
        
      case _humidityEndpoint:
        ruuviData = RuuviData(
          deviceId: deviceId,
          temperature: double.nan,
          humidity: value * 0.01, // 0.01% per LSB
          pressure: double.nan,
          timestamp: dateTime,
        );
        break;
        
      case _pressureEndpoint:
        ruuviData = RuuviData(
          deviceId: deviceId,
          temperature: double.nan,
          humidity: double.nan,
          pressure: value.toDouble(), // 1 Pa per LSB
          timestamp: dateTime,
        );
        break;
    }
    
    if (ruuviData != null) {
      measurements.add(ruuviData);
    }
  }
}
