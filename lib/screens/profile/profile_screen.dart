import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:integriscan/providers/auth_provider.dart' as custom_auth;
import 'package:integriscan/services/firestore_service.dart';
import 'package:integriscan/constant.dart';

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
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: userProfile == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Modern App Bar with Back Button
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // Back Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Profile Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                ((userProfile['firstName'] ?? '') as String).isNotEmpty
                                    ? (userProfile['firstName'][0] + ((userProfile['lastName'] ?? '').toString().isNotEmpty ? userProfile['lastName'][0] : '')).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Profile Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ((userProfile['firstName'] ?? '') + ' ' + (userProfile['lastName'] ?? '')).trim(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Stats Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Profile Information',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Update your personal information and account settings.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      color: Colors.white.withOpacity(0.7),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      user?.email ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Edit Form Section
                          const Text(
                            'Personal Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Form Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // First Name
                                  _buildModernTextField(
                                    initialValue: userProfile['firstName'] ?? '',
                                    labelText: 'First Name',
                                    onSaved: (v) => _firstName = v,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Last Name
                                  _buildModernTextField(
                                    initialValue: userProfile['lastName'] ?? '',
                                    labelText: 'Last Name',
                                    onSaved: (v) => _lastName = v,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // New Password
                                  _buildModernTextField(
                                    labelText: 'New Password (Optional)',
                                    obscureText: true,
                                    onSaved: (v) => _newPassword = v,
                                  ),
                                  const SizedBox(height: 32),
                                  
                                  // Save Button
                                  _loading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _buildModernButton(),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModernTextField({
    String? initialValue,
    required String labelText,
    bool obscureText = false,
    required void Function(String?) onSaved,
  }) {
    return TextFormField(
      initialValue: initialValue,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        filled: true,
        fillColor: kPrimaryLightColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onSaved: onSaved,
    );
  }
  Widget _buildModernButton() {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);
    final userProfile = authProvider.userProfile;
    final user = authProvider.user;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () async {
          _formKey.currentState?.save();
          setState(() => _loading = true);
          try {
            // Update Firestore profile
            if (user != null) {
              await FirestoreService.saveUser(
                uid: user.uid,
                firstName: _firstName ?? userProfile?['firstName'] ?? '',
                lastName: _lastName ?? userProfile?['lastName'] ?? '',
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
                SnackBar(
                  content: const Text('Profile updated successfully!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
        child: const Text('Save Changes'),
      ),
    );
  }
}
