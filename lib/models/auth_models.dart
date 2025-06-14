import 'package:firebase_auth/firebase_auth.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthResult {
  final bool success;
  final String? error;
  final User? user;
  
  const AuthResult({
    required this.success,
    this.error,
    this.user,
  });
  
  factory AuthResult.success(User? user) => AuthResult(
    success: true,
    user: user,
  );
  
  factory AuthResult.failure(String error) => AuthResult(
    success: false,
    error: error,
  );
}

class ValidationResult {
  final bool isValid;
  final String? error;
  
  const ValidationResult({required this.isValid, this.error});
  
  factory ValidationResult.valid() => const ValidationResult(isValid: true);
  factory ValidationResult.invalid(String error) => ValidationResult(isValid: false, error: error);
}
