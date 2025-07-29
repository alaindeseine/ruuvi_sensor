/// A single measurement from RuuviTag history
class RuuviHistoryMeasurement {
  final DateTime timestamp;
  final double? temperature;  // °C
  final double? humidity;     // %
  final double? pressure;     // hPa

  const RuuviHistoryMeasurement({
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.pressure,
  });

  /// Returns the temperature in Celsius
  double? getTemperatureCelsius() => temperature;

  /// Returns the temperature in Fahrenheit
  double? getTemperatureFahrenheit() {
    if (temperature == null) return null;
    return (temperature! * 9 / 5) + 32;
  }

  /// Returns the humidity as a percentage
  double? getHumidityPercent() => humidity;

  /// Returns the pressure in hPa
  double? getPressureHPa() => pressure;

  /// Returns the pressure in mmHg
  double? getPressureMmHg() {
    if (pressure == null) return null;
    return pressure! * 0.750062;
  }

  /// Returns the pressure in inHg
  double? getPressureInHg() {
    if (pressure == null) return null;
    return pressure! * 0.02953;
  }

  /// Returns true if this measurement has all sensor values
  bool isComplete() {
    return temperature != null && humidity != null && pressure != null;
  }

  /// Returns a list of available sensor types in this measurement
  List<String> getAvailableSensors() {
    final sensors = <String>[];
    if (temperature != null) sensors.add('temperature');
    if (humidity != null) sensors.add('humidity');
    if (pressure != null) sensors.add('pressure');
    return sensors;
  }

  /// Returns the measurement as a map
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'isComplete': isComplete(),
      'availableSensors': getAvailableSensors(),
    };
  }

  /// Creates a RuuviHistoryMeasurement from a map
  factory RuuviHistoryMeasurement.fromMap(Map<String, dynamic> map) {
    return RuuviHistoryMeasurement(
      timestamp: DateTime.parse(map['timestamp']),
      temperature: map['temperature']?.toDouble(),
      humidity: map['humidity']?.toDouble(),
      pressure: map['pressure']?.toDouble(),
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(timestamp.toIso8601String());
    if (temperature != null) {
      buffer.write(' | ${temperature!.toStringAsFixed(2)}°C');
    }
    if (humidity != null) {
      buffer.write(' | ${humidity!.toStringAsFixed(1)}%');
    }
    if (pressure != null) {
      buffer.write(' | ${pressure!.toStringAsFixed(1)} hPa');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuuviHistoryMeasurement &&
        other.timestamp == timestamp &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.pressure == pressure;
  }

  @override
  int get hashCode => Object.hash(timestamp, temperature, humidity, pressure);
}

/// Collection of history measurements with utility methods
class RuuviHistoryCollection {
  final List<RuuviHistoryMeasurement> measurements;
  final String deviceId;

  const RuuviHistoryCollection({
    required this.measurements,
    required this.deviceId,
  });

  /// Returns the number of measurements
  int get length => measurements.length;

  /// Returns true if the collection is empty
  bool get isEmpty => measurements.isEmpty;

  /// Returns true if the collection is not empty
  bool get isNotEmpty => measurements.isNotEmpty;

  /// Returns the first measurement (oldest)
  RuuviHistoryMeasurement? get first => measurements.isNotEmpty ? measurements.first : null;

  /// Returns the last measurement (newest)
  RuuviHistoryMeasurement? get last => measurements.isNotEmpty ? measurements.last : null;

  /// Returns the time range covered by this collection
  Duration? get timeRange {
    if (measurements.length < 2) return null;
    return measurements.last.timestamp.difference(measurements.first.timestamp);
  }

  /// Returns measurements filtered by date range
  RuuviHistoryCollection filterByDateRange(DateTime start, DateTime end) {
    final filtered = measurements.where((m) =>
        m.timestamp.isAfter(start) && m.timestamp.isBefore(end)).toList();
    return RuuviHistoryCollection(measurements: filtered, deviceId: deviceId);
  }

  /// Returns only complete measurements (all sensors present)
  RuuviHistoryCollection getCompleteOnly() {
    final complete = measurements.where((m) => m.isComplete()).toList();
    return RuuviHistoryCollection(measurements: complete, deviceId: deviceId);
  }

  /// Returns average values for the collection
  Map<String, double?> getAverages() {
    if (measurements.isEmpty) return {'temperature': null, 'humidity': null, 'pressure': null};

    final temps = measurements.where((m) => m.temperature != null).map((m) => m.temperature!);
    final hums = measurements.where((m) => m.humidity != null).map((m) => m.humidity!);
    final pres = measurements.where((m) => m.pressure != null).map((m) => m.pressure!);

    return {
      'temperature': temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : null,
      'humidity': hums.isNotEmpty ? hums.reduce((a, b) => a + b) / hums.length : null,
      'pressure': pres.isNotEmpty ? pres.reduce((a, b) => a + b) / pres.length : null,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('RuuviHistoryCollection for $deviceId:');
    buffer.writeln('  Measurements: ${measurements.length}');
    if (measurements.isNotEmpty) {
      buffer.writeln('  Time range: ${first!.timestamp} to ${last!.timestamp}');
      final averages = getAverages();
      if (averages['temperature'] != null) {
        buffer.writeln('  Avg temperature: ${averages['temperature']!.toStringAsFixed(2)}°C');
      }
      if (averages['humidity'] != null) {
        buffer.writeln('  Avg humidity: ${averages['humidity']!.toStringAsFixed(1)}%');
      }
      if (averages['pressure'] != null) {
        buffer.writeln('  Avg pressure: ${averages['pressure']!.toStringAsFixed(1)} hPa');
      }
    }
    return buffer.toString();
  }
}
