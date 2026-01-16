import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/settings_page.dart';
import 'package:internship_duxoff_hub/views/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isDeletingAccount = false;

  // User data from API
  Map<String, dynamic> userData = {
    'userId': '',
    'name': '',
    'washes': '0',
    'dryings': '0',
    'mobile': '',
    'status': '',
  };

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadProfileImage();
  }

  /// Fetch user profile from API using HomeApi service
  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);

    try {
      // Check if user is authenticated
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('user_mobile');
      final sessionToken = prefs.getString('session_token');

      if (mobile == null || sessionToken == null) {
        _showSnackBar('Session expired. Please login again.', isError: true);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _navigateToLogin();
        }
        return;
      }

      // Call API using HomeApi service
      final data = await HomeApi.getUserProfile();

      setState(() {
        userData = {
          'userId': data['userid']?.toString() ?? '',
          'name': (data['username'] ?? '').toString(),
          'washes': data['numberofWashes']?.toString() ?? '0',
          'dryings': data['numberofDryers']?.toString() ?? '0',
          'mobile': data['usermobile'] ?? mobile,
          'status': data['userstatus'] ?? '',
        };
        _isLoading = false;
      });

      // Update stored username if changed
      if (data['username'] != null) {
        await prefs.setString('user_name', data['username']);
      }
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Error loading profile';
      if (e.toString().contains('User not authenticated')) {
        errorMessage = 'Session expired. Please login again.';
        _navigateToLogin();
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error. Check your connection.';
      } else {
        errorMessage = 'Error loading profile: ${e.toString()}';
      }

      _showSnackBar(errorMessage, isError: true);
      debugPrint('Profile fetch error: $e');
    }
  }

  /// Load profile image from SharedPreferences
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('profile_image_path');

      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          setState(() {
            _profileImage = file;
          });
        } else {
          // Image file doesn't exist, clear the stored path
          await prefs.remove('profile_image_path');
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  /// Save profile image path to SharedPreferences
  Future<void> _saveProfileImagePath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', path);
    } catch (e) {
      debugPrint('Error saving profile image path: $e');
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Profile Picture',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSourceOption(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _buildImageSourceOption(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImage != null) ...[
                const SizedBox(height: 8),
                _buildImageSourceOption(
                  icon: Icons.delete,
                  title: 'Remove Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage();
                  },
                  isDestructive: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : const Color(0xFF4DB6AC),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });

        // Save image path to SharedPreferences
        await _saveProfileImagePath(pickedFile.path);

        _showSnackBar('Profile picture updated', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error selecting image', isError: true);
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _profileImage = null;
    });

    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path');

    _showSnackBar('Profile picture removed', isError: false);
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete Your Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE57373),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Deactivating your account will disable access and hide your data from the system.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This action is reversible. You can reactivate your account anytime by logging in again.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteAccount();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57373),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete My Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Go back to Profile',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // TODO: When delete account API is available, call it here:
      // await HomeApi.deleteAccount();

      // For now, just clear local data
      await prefs.clear();

      // Delete profile image file if exists
      if (_profileImage != null) {
        try {
          await _profileImage!.delete();
        } catch (e) {
          debugPrint('Error deleting profile image file: $e');
        }
      }

      setState(() => _isDeletingAccount = false);

      _showSnackBar('Account deleted successfully', isError: false);

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      setState(() => _isDeletingAccount = false);
      _showSnackBar('Error deleting account', isError: true);
      debugPrint('Delete account error: $e');
    }
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          ),
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4DB6AC)),
            )
          : RefreshIndicator(
              onRefresh: _fetchUserProfile,
              color: const Color(0xFF4DB6AC),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Profile Image
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey.shade500,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Profile Information Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildProfileRow(
                              'User ID',
                              userData['userId']!,
                              isFirst: true,
                            ),
                            _buildProfileRow('Name', userData['name']!),
                            _buildProfileRow(
                              'No. of Washes',
                              userData['washes']!,
                            ),
                            _buildProfileRow(
                              'No. of Dryings',
                              userData['dryings']!,
                            ),
                            _buildProfileRow(
                              'Mobile No.',
                              userData['mobile']!,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Delete Account Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isDeletingAccount
                              ? null
                              : _showDeleteAccountDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE57373),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: const Color(
                              0xFFE57373,
                            ).withOpacity(0.5),
                          ),
                          child: _isDeletingAccount
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Delete Your Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileRow(
    String label,
    String value, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
