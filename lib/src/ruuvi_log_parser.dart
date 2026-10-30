/// One packet received from the Nordic UART TX characteristic during a
/// history (log) read.
///
/// Reference: `app_sensor.c` in ruuvi.firmware.c (`send_field`,
/// `app_sensor_send_eof`, `app_sensor_send_timeout`) and `re_log_write_data`
/// in ruuvi.endpoints.c.
sealed class RuuviLogPacket {
  const RuuviLogPacket();
}

/// A single logged value.
class RuuviLogValue extends RuuviLogPacket {
  /// Unix time in seconds.
  final int timestamp;

  /// `temperature`, `humidity` or `pressure`.
  final String sensorType;

  /// °C, % or hPa depending on [sensorType].
  final double value;

  const RuuviLogValue(this.timestamp, this.sensorType, this.value);
}

/// The tag has sent every stored value.
class RuuviLogEnd extends RuuviLogPacket {
  const RuuviLogEnd();
}

/// The tag aborted the transfer (firmware internal timeout).
class RuuviLogAborted extends RuuviLogPacket {
  const RuuviLogAborted();
}

const int _packetLength = 11;
const int _opLogValueWrite = 0x10;
const int _opTimeout = 0xE0;

/// Parses one log packet. Returns `null` for packets that are not part of a
/// log transfer (wrong length, unknown operation or sensor endpoint).
RuuviLogPacket? parseRuuviLogPacket(List<int> data) {
  if (data.length != _packetLength) return null;

  final source = data[1];
  final op = data[2];

  if (op == _opTimeout) return const RuuviLogAborted();
  if (op != _opLogValueWrite) return null;

  // End of log: the whole 8-byte payload (timestamp AND value) is 0xFF.
  // Checking the value alone is not enough: -0.01 °C is also 0xFFFFFFFF.
  if (data.skip(3).every((b) => b == 0xFF)) return const RuuviLogEnd();

  final timestamp = _uint32(data, 3);
  final raw = _uint32(data, 7);
  final value = raw > 0x7FFFFFFF ? raw - 0x100000000 : raw;

  switch (source) {
    case 0x30:
      return RuuviLogValue(timestamp, 'temperature', value / 100.0);
    case 0x31:
      return RuuviLogValue(timestamp, 'humidity', value / 100.0);
    case 0x32:
      // Logged in Pa, exposed in hPa.
      return RuuviLogValue(timestamp, 'pressure', value / 100.0);
    default:
      return null;
  }
}

int _uint32(List<int> data, int offset) =>
    (data[offset] << 24) |
    (data[offset + 1] << 16) |
    (data[offset + 2] << 8) |
    data[offset + 3];
