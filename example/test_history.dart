import 'package:ruuvi_sensor/ruuvi_sensor.dart';

/// Simple test example for RuuviHistoryReader
void main() async {
  final historyReader = RuuviHistoryReader();
  final deviceId = 'CC:AF:FD:5D:26:DE'; // Replace with your RuuviTag MAC address

  try {
    print('🔍 Reading device information...');
    final deviceInfo = await historyReader.getDeviceInformation(deviceId);
    print(deviceInfo);

    print('\n📊 Reading history (last 24 hours)...');
    final history = await historyReader.getHistory(
      deviceId,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    print('📈 Retrieved ${history.length} measurements');
    if (history.isNotEmpty) {
      print('📅 Time range: ${history.first?.timestamp} to ${history.last?.timestamp}');
      
      final averages = history.getAverages();
      if (averages['temperature'] != null) {
        print('🌡️ Average temperature: ${averages['temperature']!.toStringAsFixed(2)}°C');
      }
      if (averages['humidity'] != null) {
        print('💧 Average humidity: ${averages['humidity']!.toStringAsFixed(1)}%');
      }
      if (averages['pressure'] != null) {
        print('📊 Average pressure: ${averages['pressure']!.toStringAsFixed(1)} hPa');
      }

      print('\n📋 First 5 measurements:');
      for (int i = 0; i < 5 && i < history.length; i++) {
        print('  ${history.measurements[i]}');
      }
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}
