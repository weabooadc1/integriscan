import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:integriscan/services/auth_service.dart';
import 'package:integriscan/services/firestore_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/exceptions/app_exceptions.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthProvider() {
    _init();
  }
  // Initialize and listen to auth state changes
  void _init() {
    _isLoading = true;
    notifyListeners();
    
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      final previousUser = _user;
      _user = user;
      _isLoading = false;
      notifyListeners();
      
      // If user just signed in (from null to user), sync reports for cross-device compatibility
      if (previousUser == null && user != null) {
        Logger.info('User signed in, syncing reports for cross-device access...');
        try {
          // Sync reports from cloud (download reports from other devices)
          await ReportService.syncReportsFromCloud(userId: user.uid);
          // Also sync flagged reports
          await ReportService.syncFlaggedReportsFromCloud(userId: user.uid);
          Logger.info('Cross-device report sync completed successfully');
        } catch (e) {
          Logger.error('Error during sign-in report sync', e);
          // Don't block sign-in if sync fails
        }
      }
    });
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.secureLog("Sign in successful", userCredential.user?.email ?? 'unknown');
      _user = userCredential.user;
      await fetchUserProfile();
      
      // Trigger cross-device report sync after successful sign-in
      if (_user != null) {
        try {
          Logger.info('Syncing reports after sign-in for cross-device access...');
          await ReportService.syncReportsFromCloud(userId: _user!.uid);
          await ReportService.syncFlaggedReportsFromCloud(userId: _user!.uid);
          Logger.info('Post-signin report sync completed');
        } catch (e) {
          Logger.error('Error during post-signin report sync', e);
          // Don't fail sign-in if sync fails
        }
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      Logger.error("Sign in AuthException", e.message);
      _setError(e.message);
      _setLoading(false);
      return false;
    } on NetworkException catch (e) {
      Logger.error("Sign in NetworkException", e.message);
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      Logger.error("Sign in unexpected error", e);
      _setError('An unexpected error occurred during sign in');
      _setLoading(false);
      return false;
    }
  }  // Register with email and password
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    _setLoading(true);
    _clearError();
      try {
      Logger.secureLog("AuthProvider: Attempting to register with email", email);
      final userCredential = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      Logger.secureLog("AuthProvider: Registration successful for", userCredential.user?.email ?? 'unknown');
      _user = userCredential.user;
      
      // Update user profile with name if provided
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        String displayName = '';
        if (firstName.isNotEmpty) displayName += firstName;
        if (lastName.isNotEmpty) {
          if (displayName.isNotEmpty) displayName += ' ';
          displayName += lastName;
        }
          try {
          await _user?.updateDisplayName(displayName);
          Logger.info("AuthProvider: Updated user display name to: $displayName");
        } catch (e) {
          Logger.error("AuthProvider: Error updating display name", e);
          // Don't fail the registration if only the profile update fails
        }
      }
      
      _setLoading(false);
      notifyListeners();      return true;
    } on AuthException catch (e) {
      Logger.error("Registration AuthException", e.message);
      _setError(e.message);
      _setLoading(false);
      return false;
    } on NetworkException catch (e) {
      Logger.error("Registration NetworkException", e.message);
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      Logger.error("Registration unexpected error", e);
      _setError('An unexpected error occurred during registration');
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.signOut();
      _setLoading(false);
    } catch (e) {
      _setError(_handleFirebaseAuthError(e));
      _setLoading(false);
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(_handleFirebaseAuthError(e));
      _setLoading(false);
      return false;
    }
  }

  // Fetch user profile from Firestore
  Future<void> fetchUserProfile() async {
    if (_user != null) {
      _userProfile = await FirestoreService.getUser(_user!.uid);
      notifyListeners();
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setError(String? value) {
    if (_error != value) {
      _error = value;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
  // Handle Firebase Auth Errors
  String _handleFirebaseAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid email or password. Please check your credentials.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'email-already-in-use':
          return 'The email address is already in use.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'operation-not-allowed':
          return 'This operation is not allowed.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many requests. Try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'credential-already-in-use':
          return 'This credential is already associated with a different user account.';
        case 'requires-recent-login':
          return 'This operation requires recent authentication. Please log in again.';
        default:
          return 'An unexpected error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}
