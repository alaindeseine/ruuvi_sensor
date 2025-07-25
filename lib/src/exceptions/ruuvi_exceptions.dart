class RuuviException implements Exception {
  final String message;
  const RuuviException(this.message);
  
  @override
  String toString() => 'RuuviException: $message';
}

class RuuviConnectionException extends RuuviException {
  const RuuviConnectionException(super.message);
}

class RuuviDataException extends RuuviException {
  const RuuviDataException(super.message);
}