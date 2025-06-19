import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:integriscan/providers/auth_provider.dart' as custom_auth;
import 'package:integriscan/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _firstName;
  String? _lastName;
  String? _newPassword;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);
    final userProfile = authProvider.userProfile;
    final user = authProvider.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: userProfile == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      initialValue: userProfile['firstName'] ?? '',
                      decoration: const InputDecoration(labelText: 'First Name'),
                      onSaved: (v) => _firstName = v,
                    ),
                    TextFormField(
                      initialValue: userProfile['lastName'] ?? '',
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      onSaved: (v) => _lastName = v,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'New Password'),
                      obscureText: true,
                      onSaved: (v) => _newPassword = v,
                    ),
                    const SizedBox(height: 24),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () async {
                              _formKey.currentState?.save();
                              setState(() => _loading = true);
                              try {
                                // Update Firestore profile
                                if (user != null) {
                                  await FirestoreService.saveUser(
                                    uid: user.uid,
                                    firstName: _firstName ?? userProfile['firstName'] ?? '',
                                    lastName: _lastName ?? userProfile['lastName'] ?? '',
                                    email: user.email ?? '',
                                  );
                                  await authProvider.fetchUserProfile();
                                }
                                // Update password if provided
                                if (_newPassword != null && _newPassword!.isNotEmpty && user != null) {
                                  await user.updatePassword(_newPassword!);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
                                  );
                                  Navigator.of(context).pop(); // Go back to home screen
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                            child: const Text('Save Changes'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
