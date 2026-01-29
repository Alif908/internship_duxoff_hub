import 'dart:io';

import 'package:flutter/material.dart';

import 'package:internship_duxoff_hub/services/home_api_service.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/contact_us_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/profile_page.dart';
import 'package:internship_duxoff_hub/views/home%20screen/settings%20page/wash_history.dart';

import 'package:internship_duxoff_hub/views/home%20screen/about_us.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';
import 'package:internship_duxoff_hub/views/loginpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String _userName = '';
  String _userMobile = '';
  int _totalWashes = 0;
  int _totalDryings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> makeCall() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final Uri uri = Uri.parse('tel:7592990849');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      _userName = prefs.getString('user_name') ?? '';
      _userMobile = prefs.getString('user_mobile') ?? '';

      setState(() {});

      try {
        final profileData = await HomeApi.getUserProfile();

        setState(() {
          _userName =
              (profileData['username'] ?? _userName).toString().toUpperCase();
          _userMobile = profileData['usermobile'] ?? _userMobile;
          _totalWashes = profileData['numberofWashes'] ?? 0;
          _totalDryings = profileData['numberofDryers'] ?? 0;
        });

        if (profileData['username'] != null) {
          await prefs.setString('user_name', profileData['username']);
        }
      } catch (e) {
        debugPrint('Failed to fetch profile from API: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading user data: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4DB6AC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear all session-related data
      await prefs.remove('session_token');
      await prefs.remove('sessionToken');
      await prefs.remove('user_status');
      await prefs.remove('current_otp');
      await prefs.remove('otp_timestamp');
      await prefs.remove('user_mobile');
      await prefs.remove('usermobile');
      await prefs.remove('user_name');
      await prefs.remove('username');
      await prefs.remove('user_id');
      await prefs.remove('userid');

      setState(() => _isLoggingOut = false);

      _showSnackBar('Logged out successfully', isError: false);

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoggingOut = false);
      _showSnackBar('Error logging out', isError: true);
      debugPrint('Logout error: $e');
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => QKWashHome()),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _settingsTile(
                  title: 'Profile',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfilePage()),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  title: 'Wash history',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WashHistoryPage()),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  title: 'About us',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AboutUsPage()),
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  title: 'Contact us',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ContactUsPage()),
                    );
                  },
                ),
                _divider(),
                // ✅ LOGOUT BUTTON ADDED HERE
                _settingsTile(
                  title: 'Logout',
                  onTap: _isLoggingOut ? () {} : _showLogoutDialog,
                  isLogout: true,
                  isLoading: _isLoggingOut,
                ),
              ],
            ),
          ),
          Container(
            height: 52,
            width: double.infinity,
            color: const Color(0xFF4DB6AC),
            alignment: Alignment.center,
            child: InkWell(
              onTap: () {
                makeCall();
              },
              child: const Text(
                'For any enquiry  +91 7592990849',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isLogout
                    ? (isLoading ? Colors.grey : Colors.red)
                    : Colors.black,
              ),
            ),
            const Spacer(),
            // Show loading indicator when logging out
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
                ),
              )
            else
              const Icon(Icons.chevron_right, size: 22, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 0.8, color: Color(0xFFE0E0E0)),
    );
  }
}
