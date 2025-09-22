import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _firstName;
  String? _lastName;
  bool _loading = false;
  bool _showPasswordFields = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  Map<String, dynamic>? _localUserProfile;
  bool _profileLoading = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context, listen: false);
    if (authProvider.userProfile != null) {
      setState(() {
        _localUserProfile = Map<String, dynamic>.from(authProvider.userProfile!);
        _profileLoading = false;
      });
    } else {
      await authProvider.fetchUserProfile();
      setState(() {
        _localUserProfile = Map<String, dynamic>.from(authProvider.userProfile ?? {});
        _profileLoading = false;
      });
    }
  }

  // Secure password change method
  Future<bool> _changePassword() async {
    final user = Provider.of<custom_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return false;

    try {
      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // If re-authentication succeeds, update password
      await user.updatePassword(_newPasswordController.text);
      
      return true;
    } catch (e) {
      // Handle specific error types
      String errorMessage = 'Failed to change password';
      
      if (e.toString().contains('wrong-password') || 
          e.toString().contains('invalid-credential')) {
        errorMessage = 'Current password is incorrect';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'New password is too weak';
      } else if (e.toString().contains('requires-recent-login')) {
        errorMessage = 'Please sign out and sign in again before changing password';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return false;
    }
  }

  // Enhanced password change section
  Widget _buildPasswordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Password Section Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _showPasswordFields ? Colors.red.withOpacity(0.1) : kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPasswordFields = !_showPasswordFields;
                        if (!_showPasswordFields) {
                          // Clear password fields when hiding
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                          // Reset password visibility states
                          _obscureCurrentPassword = true;
                          _obscureNewPassword = true;
                          _obscureConfirmPassword = true;
                        }
                      });
                    },
                    icon: Icon(
                      _showPasswordFields ? Icons.close : Icons.edit,
                      color: _showPasswordFields ? Colors.red[700] : kPrimaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_showPasswordFields) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Security Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.1),
                          Colors.orange.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.orange[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security Verification',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your current password to verify your identity before making changes.',
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Current Password
                  _buildModernTextField(
                    labelText: 'Current Password',
                    obscureText: _obscureCurrentPassword,
                    icon: Icons.lock_outline,
                    controller: _currentPasswordController,
                    isPasswordField: true,
                    onTogglePasswordVisibility: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                    onSaved: (v) {},
                  ),
                  const SizedBox(height: 20),
                  
                  // New Password
                  _buildModernTextField(
                    labelText: 'New Password',
                    obscureText: _obscureNewPassword,
                    icon: Icons.lock_reset,
                    controller: _newPasswordController,
                    isPasswordField: true,
                    onTogglePasswordVisibility: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'New password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onSaved: (v) {},
                  ),
                  const SizedBox(height: 20),
                  
                  // Confirm New Password
                  _buildModernTextField(
                    labelText: 'Confirm New Password',
                    obscureText: _obscureConfirmPassword,
                    icon: Icons.lock_clock,
                    controller: _confirmPasswordController,
                    isPasswordField: true,
                    onTogglePasswordVisibility: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onSaved: (v) {},
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Keep your account secure by regularly updating your password.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);
    final user = authProvider.user;
    final userProfile = _localUserProfile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _profileLoading || userProfile == null
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Modern App Bar
                  SliverAppBar(
                    expandedHeight: 160,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          color: kPrimaryColor,
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                            child: Row(
                              children: [
                                // Profile Avatar with modern design
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      ((userProfile['firstName'] ?? '') as String).isNotEmpty
                                          ? (userProfile['firstName'][0] + ((userProfile['lastName'] ?? '').toString().isNotEmpty ? userProfile['lastName'][0] : '')).toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: kPrimaryColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Profile Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ((userProfile['firstName'] ?? '') + ' ' + (userProfile['lastName'] ?? '')).trim(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.email ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Main Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Personal Information Section
                          _buildSectionHeader('Personal Information', Icons.person),
                          const SizedBox(height: 16),
                          
                          // Modern Form Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // First Name
                                    _buildModernTextField(
                                      initialValue: userProfile['firstName'] ?? '',
                                      labelText: 'First Name',
                                      icon: Icons.person_outline,
                                      onSaved: (v) => _firstName = v,
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Last Name
                                    _buildModernTextField(
                                      initialValue: userProfile['lastName'] ?? '',
                                      labelText: 'Last Name',
                                      icon: Icons.person_outline,
                                      onSaved: (v) => _lastName = v,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Security Section
                          _buildSectionHeader('Security & Privacy', Icons.lock_outline),
                          const SizedBox(height: 16),
                          
                          // Password Section
                          _buildPasswordSection(),
                          
                          const SizedBox(height: 32),
                          
                          // Save Button
                          _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildModernButton(),
                              
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModernTextField({
    String? initialValue,
    required String labelText,
    bool obscureText = false,
    required void Function(String?) onSaved,
    TextEditingController? controller,
    String? Function(String?)? validator,
    IconData? icon,
    bool? isPasswordField,
    VoidCallback? onTogglePasswordVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: TextFormField(
        initialValue: controller == null ? initialValue : null,
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: icon != null 
              ? Icon(icon, color: Colors.grey[600], size: 20)
              : null,
          suffixIcon: isPasswordField == true
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  onPressed: onTogglePasswordVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: icon != null ? 16 : 20,
            vertical: 20,
          ),
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildStatCard(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
  Widget _buildModernButton() {
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);
    final userProfile = authProvider.userProfile;
    final user = authProvider.user;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () async {
          // Validate form including password fields if shown
          if (!_formKey.currentState!.validate()) {
            return;
          }
          
          _formKey.currentState?.save();
          setState(() => _loading = true);
          
          try {
            // Update profile information
            if (user != null) {
              await FirestoreService.saveUser(
                uid: user.uid,
                firstName: _firstName ?? userProfile?['firstName'] ?? '',
                lastName: _lastName ?? userProfile?['lastName'] ?? '',
                email: user.email ?? '',
              );
              await authProvider.fetchUserProfile();
            }
            
            // Handle password change if password fields are shown
            bool passwordChangeSuccess = true;
            if (_showPasswordFields && 
                _currentPasswordController.text.isNotEmpty &&
                _newPasswordController.text.isNotEmpty) {
              passwordChangeSuccess = await _changePassword();
            }
            
            if (mounted && passwordChangeSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(_showPasswordFields && _newPasswordController.text.isNotEmpty
                          ? 'Updated successfully!'
                          : 'Profile updated successfully!'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF4CAF50),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
              Navigator.of(context).pop();
            }
            
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Error updating profile: $e')),
                    ],
                  ),
                  backgroundColor: const Color(0xFFE53E3E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.save_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
