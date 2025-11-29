import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fashion App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _loadingAnimationController;
  bool _isVideoInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _videoController =
          VideoPlayerController.asset('assets/images/splash.mp4');
      await _videoController.initialize();

      _videoController.play();
      _videoController.setLooping(true);

      setState(() {
        _isVideoInitialized = true;
      });

      Timer(const Duration(seconds: 20), _navigateToLogin);
    } catch (e) {
      print('❌ Error initializing splash screen: $e');

      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }

      Timer(const Duration(seconds: 20), _navigateToLogin);
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoInitialized && !_hasError)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            Container(color: Colors.black),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Animated Loading Bar
                AnimatedBuilder(
                  animation: _loadingAnimationController,
                  builder: (context, child) {
                    return Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Stack(
                        children: [
                          // Animated progress bar
                          FractionallySizedBox(
                            widthFactor: _loadingAnimationController.value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blueAccent,
                                    Colors.purpleAccent,
                                    Colors.pinkAccent,
                                    Colors.orangeAccent,
                                  ],
                                  stops: [
                                    0.0,
                                    0.33,
                                    0.66,
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Rotating loading indicator
                RotationTransition(
                  turns: _loadingAnimationController,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Loading Fashion App...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
