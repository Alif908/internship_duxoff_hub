import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internship_duxoff_hub/views/loginpage.dart';
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
      await _controller.play();

      
      _controller.addListener(_videoListener);

      debugPrint('[SplashScreen] Video playing');
    } catch (e) {
      debugPrint('[SplashScreen] Error: $e');
      if (!mounted) return;
      
      _navigateToLoginPage();
    }
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;

    
    if (_controller.value.position >= _controller.value.duration) {
      _navigateToLoginPage();
    }
  }

  void _navigateToLoginPage() {
    if (!mounted) return;

    
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
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
      backgroundColor: Colors.black,
      body: _isVideoInitialized
          ? Stack(
              children: [
                
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
                          color: Color(
                            0xFF0066B3,
                          ),
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
