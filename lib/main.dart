import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'welcome_page.dart';

import 'dart:io'; // Added for HttpOverrides

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔴 FIX: Allow development certificates (Solves some SSL Handshake errors)
  HttpOverrides.global = MyHttpOverrides();

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

// Custom HttpOverrides to ignore bad certificates in Dev
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
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
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  late Animation<double> _fadeOutAnimation;

  double _dragValue = 0.0;
  final double _maxWidth = 200.0; // Slider width
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    // Initial Fade In
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Zoom Animation for transition
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Slower zoom
    );

    _zoomAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOutExpo),
    );

    // Fade Out Animation (Starts halfway through zoom)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    setState(() {
      _dragValue += details.delta.dx;
      _dragValue = _dragValue.clamp(0.0, _maxWidth - 50); // 50 is button size
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    if (_dragValue > _maxWidth - 60) {
      _completeSplash();
    } else {
      // Reset
      setState(() {
        _dragValue = 0.0;
      });
    }
  }

  void _completeSplash() async {
    setState(() {
      _completed = true;
      _dragValue = _maxWidth - 50;
    });

    // Start Zoom
    await _zoomController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomePage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CENTER CONTENT (Logo)
          Center(
            child: AnimatedBuilder(
              animation:
                  _zoomController, // Listen to controller for multiple animations
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeOutAnimation,
                  child: Transform.scale(
                    scale: _zoomAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation, // Initial fade in
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white24, width: 1),
                            ),
                            child: const Icon(Icons.auto_awesome,
                                size: 60, color: Colors.white),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'TEXORA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight:
                                  FontWeight.w100, // Thin, modern font weight
                              letterSpacing: 8.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI FASHION DESIGN',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              letterSpacing: 4.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // BOTTOM SLIDER (Slide to Start)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: _completed
                  ? const SizedBox()
                  : Container(
                      width: _maxWidth,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Stack(
                        children: [
                          // Text
                          const Center(
                            child: Text(
                              "Slide to Start",
                              style: TextStyle(
                                color: Colors.white30,
                                letterSpacing: 2.0,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          // Draggable Button
                          Positioned(
                            left: _dragValue,
                            child: GestureDetector(
                              onHorizontalDragUpdate: _onDragUpdate,
                              onHorizontalDragEnd: _onDragEnd,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_forward,
                                    color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
