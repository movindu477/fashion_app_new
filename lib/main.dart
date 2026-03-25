import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'views/welcome_page.dart';
import 'views/homepage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/fabric_classifier_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Texora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
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
  // ── Stage 2: title reveal (slide up + scale + fade in)
  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<double> _titleScale;
  late Animation<Offset> _titleSlide;

  // ── Stage 3: subtitle + slider appear
  late AnimationController _subController;
  late Animation<double> _subFade;
  late Animation<Offset> _subSlide;

  // ── Stage 4: pulsating glow for the slider
  late AnimationController _glowController;

  // ── Stage 5: exit flash on completion
  late AnimationController _exitController;
  late Animation<double> _exitFlash;
  late Animation<double> _exitFade;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    FabricClassifierService().loadModel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the background image to ensure it shows instantly without flickering
    precacheImage(const AssetImage('assets/images/main3ori.jpg'), context);
  }

  void _initAnimations() {
    // 1. Title (slide + scale + fade)
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleFade = CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn));
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _titleController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );
    _titleScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
          parent: _titleController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );

    // 2. Subtitle + Slider (fade + slide)
    _subController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _subFade = CurvedAnimation(
        parent: _subController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn));
    _subSlide =
        Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _subController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );

    // 3. Pulsating glow for the button
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 4. Exit transition
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _exitFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _exitController,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _exitFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _exitController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeIn)),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _subController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _completeSplash() async {
    setState(() {
      _completed = true;
    });

    await _exitController.forward();

    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      Widget destination =
          user != null ? const HomePage() : const WelcomePage();

      Navigator.pushReplacement(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: destination,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuart,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Image (Static)
          Image.asset(
            'assets/images/main3ori.jpg',
            fit: BoxFit.cover,
          ),

          // ── Decorative Overlay (Lightened for better visibility)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // ── Main Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title reveal (Pure White, no shimmer)
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: ScaleTransition(
                      scale: _titleScale,
                      child: Text(
                        'TEXORA',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 78,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Subtitle Line
                FadeTransition(
                  opacity: _subFade,
                  child: SlideTransition(
                    position: _subSlide,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 1,
                          color: const Color(0xFFFF5200).withOpacity(0.5),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'FUTURE OF FASHION',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 1,
                          color: const Color(0xFFFF5200).withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Modernized Slider
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _subFade,
              child: SlideTransition(
                position: _subSlide,
                child: Center(
                  child: _completed
                      ? const SizedBox()
                      : GestureDetector(
                          onTap: () {
                            if (_completed) return;
                            _completeSplash();
                          },
                          child: Container(
                            width: 280,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5200), Color(0xFFE64A19)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFF5200).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Get Started',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .shimmer(
                            duration: 2.seconds,
                            color: Colors.white.withOpacity(0.2),
                          ),
                ),
              ),
            ),
          ),

          // ── Exit Flash
          AnimatedBuilder(
            animation: _exitController,
            builder: (context, _) {
              if (_exitController.value == 0) return const SizedBox();
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: (_exitFlash.value * (1 - _exitFade.value))
                        .clamp(0.0, 1.0),
                    child: Container(color: Colors.white),
                  ),
                  Opacity(
                    opacity: _exitFade.value,
                    child: Container(color: Colors.black),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
