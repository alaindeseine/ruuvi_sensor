/// Information about a RuuviTag device
class RuuviTagInformation {
  final String _identifier;
  final String? _manufacturer;
  final String? _model;
  final String? _firmwareVersion;
  final String? _hardwareVersion;
  final String _macAddress;

  const RuuviTagInformation({
    required String identifier,
    required String macAddress,
    String? manufacturer,
    String? model,
    String? firmwareVersion,
    String? hardwareVersion,
  })  : _identifier = identifier,
        _macAddress = macAddress,
        _manufacturer = manufacturer,
        _model = model,
        _firmwareVersion = firmwareVersion,
        _hardwareVersion = hardwareVersion;

  /// Returns the unique identifier of the RuuviTag
  /// This is either the serial number (if available) or the MAC address as fallback
  String getIdentifier() => _identifier;

  /// Returns the MAC address of the RuuviTag
  String getMacAddress() => _macAddress;

  /// Returns the manufacturer name (usually "Ruuvi Innovations Ltd")
  String? getManufacturer() => _manufacturer;

  /// Returns the model name (usually "RuuviTag")
  String? getModel() => _model;

  /// Returns the firmware version (e.g., "3.31.1")
  String? getFirmwareVersion() => _firmwareVersion;

  /// Returns the hardware version (e.g., "C")
  String? getHardwareVersion() => _hardwareVersion;

  /// Returns a display name for the RuuviTag
  /// Format: "Ruuvi XXXX" where XXXX are the last 4 characters of the identifier
  String getDisplayName() {
    final lastChars = _identifier.replaceAll(':', '').toUpperCase();
    if (lastChars.length >= 4) {
      return 'Ruuvi ${lastChars.substring(lastChars.length - 4)}';
    }
    return 'Ruuvi $lastChars';
  }

  /// Returns true if the identifier is a serial number (not a MAC address)
  bool hasSerialNumber() {
    // MAC address format: XX:XX:XX:XX:XX:XX
    return !RegExp(r'^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$')
        .hasMatch(_identifier);
  }

  /// Returns a summary of all available information
  Map<String, String?> toMap() {
    return {
      'identifier': _identifier,
      'macAddress': _macAddress,
      'manufacturer': _manufacturer,
      'model': _model,
      'firmwareVersion': _firmwareVersion,
      'hardwareVersion': _hardwareVersion,
      'displayName': getDisplayName(),
      'hasSerialNumber': hasSerialNumber().toString(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('RuuviTag Information:');
    buffer.writeln('  Identifier: $_identifier');
    buffer.writeln('  MAC Address: $_macAddress');
    buffer.writeln('  Display Name: ${getDisplayName()}');
    if (_manufacturer != null) buffer.writeln('  Manufacturer: $_manufacturer');
    if (_model != null) buffer.writeln('  Model: $_model');
    if (_firmwareVersion != null) buffer.writeln('  Firmware: $_firmwareVersion');
    if (_hardwareVersion != null) buffer.writeln('  Hardware: $_hardwareVersion');
    buffer.writeln('  Has Serial Number: ${hasSerialNumber()}');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuuviTagInformation &&
        other._identifier == _identifier &&
        other._macAddress == _macAddress;
  }

  @override
  int get hashCode => Object.hash(_identifier, _macAddress);
}
