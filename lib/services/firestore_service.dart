import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final _users = FirebaseFirestore.instance.collection('users');

  static Future<void> saveUser({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String role = 'user', // Default role is 'user', can be 'engineer' or 'admin'
  }) async {
    await _users.doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? doc.data() : null;
  }
  
  /// Update user role (Admin only function)
  static Future<void> updateUserRole(String uid, String role) async {
    await _users.doc(uid).update({
      'role': role,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
  
  /// Get users by role
  static Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    final querySnapshot = await _users.where('role', isEqualTo: role).get();
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }
}
