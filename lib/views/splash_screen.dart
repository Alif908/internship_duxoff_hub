import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internship_duxoff_hub/views/loginpage.dart';
import 'package:internship_duxoff_hub/views/qkwashome.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/vedios/splashscreen.mp4',
      );
      await _controller.initialize();

      if (!mounted) return;

      setState(() {
        _isVideoInitialized = true;
      });

      await _controller.setLooping(false);

      // Set playback speed to 4x faster
      await _controller.setPlaybackSpeed(4.0);

      await _controller.play();

      // Add listener to detect when video ends
      _controller.addListener(_videoListener);

      debugPrint('[SplashScreen] Video playing at 4x speed');
    } catch (e) {
      debugPrint('[SplashScreen] Error: $e');
      if (!mounted) return;

      // If video fails, check session and navigate
      _checkSessionAndNavigate();
    }
  }

  void _videoListener() {
    if (!_controller.value.isInitialized || _hasNavigated) return;

    // When video ends, check session and navigate
    if (_controller.value.position >= _controller.value.duration) {
      _checkSessionAndNavigate();
    }
  }

  Future<void> _checkSessionAndNavigate() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user has valid session
      final sessionToken = prefs.getString('session_token');
      final userId = prefs.getInt('user_id');
      final userMobile = prefs.getString('user_mobile');

      debugPrint('========== SESSION CHECK ==========');
      debugPrint('Session Token: ${sessionToken != null ? "EXISTS" : "NULL"}');
      debugPrint('User ID: $userId');
      debugPrint('User Mobile: $userMobile');
      debugPrint('===================================');

      // Restore system UI
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );

      if (!mounted) return;

      // If session exists, go to home, otherwise go to login
      if (sessionToken != null &&
          sessionToken.isNotEmpty &&
          userId != null &&
          userId > 0 &&
          userMobile != null &&
          userMobile.isNotEmpty) {
        debugPrint('✅ Valid session found - Navigating to Home');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const QKWashHome()),
        );
      } else {
        debugPrint('❌ No valid session - Navigating to Login');

        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    } catch (e) {
      debugPrint('Error checking session: $e');

      // On error, go to login page
      if (!mounted) return;

      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      body: _isVideoInitialized
          ? Stack(
              children: [
                // Video Background
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                // App Name Overlay
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.40),
                    Center(
                      child: Text(
                        'Qkwash',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0066B3),
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
