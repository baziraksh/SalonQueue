/// Base exception class for the application
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() =>
      'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception for network-related errors
class NetworkException extends AppException {
  NetworkException(super.message, {super.code});
}

/// Exception for validation errors
class ValidationException extends AppException {
  ValidationException(super.message, {super.code});
}

/// Exception for authentication errors
class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

/// Exception for server errors
class ServerException extends AppException {
  ServerException(super.message, {super.code});
}

/// Exception for cache errors
class CacheException extends AppException {
  CacheException(super.message, {super.code});
}
