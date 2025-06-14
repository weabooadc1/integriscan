/// Exception classes for better error handling
class AuthException implements Exception {
  final String message;
  final String? code;
  
  const AuthException(this.message, {this.code});
  
  @override
  String toString() => 'AuthException: $message${code != null ? ' (Code: $code)' : ''}';
}

class ValidationException implements Exception {
  final String message;
  final String field;
  
  const ValidationException(this.message, this.field);
  
  @override
  String toString() => 'ValidationException: $message (Field: $field)';
}

class NetworkException implements Exception {
  final String message;
  
  const NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}
