import 'package:integriscan/models/auth_models.dart';

class ValidationUtils {
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult.invalid("Email is required");
    }
    
    // More robust email validation
    const emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    final regex = RegExp(emailPattern);
    
    if (!regex.hasMatch(email)) {
      return ValidationResult.invalid("Please enter a valid email address");
    }
    
    return ValidationResult.valid();
  }
  
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult.invalid("Password is required");
    }
    
    if (password.length < 8) {
      return ValidationResult.invalid("Password must be at least 8 characters long");
    }
    
    // Check for at least one uppercase, lowercase, number, and special character
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]').hasMatch(password)) {
      return ValidationResult.invalid("Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character");
    }
    
    return ValidationResult.valid();
  }
  
  static ValidationResult validateName(String name, String fieldName) {
    if (name.isEmpty) {
      return ValidationResult.invalid("$fieldName is required");
    }
    
    if (name.length < 2) {
      return ValidationResult.invalid("$fieldName must be at least 2 characters long");
    }
    
    // Allow only letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name)) {
      return ValidationResult.invalid("$fieldName can only contain letters, spaces, hyphens, and apostrophes");
    }
    
    return ValidationResult.valid();
  }
  
  static ValidationResult validatePasswordMatch(String password, String confirmPassword) {
    if (password != confirmPassword) {
      return ValidationResult.invalid("Passwords do not match");
    }
    return ValidationResult.valid();
  }
}
