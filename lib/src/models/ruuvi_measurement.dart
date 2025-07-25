import 'ruuvi_data.dart';

class RuuviMeasurement {
  final List<RuuviData> measurements;
  final DateTime startTime;
  final DateTime endTime;
  final int totalCount;

  const RuuviMeasurement({
    required this.measurements,
    required this.startTime,
    required this.endTime,
    required this.totalCount,
  });
}
