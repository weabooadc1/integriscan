import 'package:flutter/foundation.dart';

class Logger {
  static void debug(String message) {
    if (kDebugMode) {
      print('[DEBUG] $message');
    }
  }
  
  static void info(String message) {
    if (kDebugMode) {
      print('[INFO] $message');
    }
  }
  
  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      print('[ERROR] $message${error != null ? ': $error' : ''}');
    }
  }
  
  static void secureLog(String message, String sensitiveData) {
    if (kDebugMode) {
      // Only log first and last character for sensitive data
      final masked = sensitiveData.length > 2 
          ? '${sensitiveData[0]}***${sensitiveData[sensitiveData.length - 1]}'
          : '***';
      print('[SECURE] $message: $masked');
    }
  }
}
