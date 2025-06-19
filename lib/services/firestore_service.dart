import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final _users = FirebaseFirestore.instance.collection('users');

  static Future<void> saveUser({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await _users.doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    });
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? doc.data() : null;
  }
}
