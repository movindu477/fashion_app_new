import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'views/welcome_page.dart';
import 'views/homepage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/fabric_classifier_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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
  // ── Stage 1: background image fade-in
  late AnimationController _bgController;
  late Animation<double> _bgFade;

  // ── Stage 2: title reveal (slide up + scale + fade in)
  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<double> _titleScale;
  late Animation<Offset> _titleSlide;

  // ── Stage 3: subtitle + slider appear
  late AnimationController _subController;
  late Animation<double> _subFade;
  late Animation<Offset> _subSlide;

  // ── Stage 4: shimmer sweep across the title
  late AnimationController _shimmerController;

  // ── Stage 5: pulsating glow for the slider
  late AnimationController _glowController;

  // ── Stage 6: exit flash on completion
  late AnimationController _exitController;
  late Animation<double> _exitFlash;
  late Animation<double> _exitFade;

  double _dragValue = 0.0;
  final double _maxWidth = 240.0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    FabricClassifierService().loadModel();

    // 1. Background image (fade)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _bgController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
    );

    // 2. Title (slide + scale + fade)
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _titleFade = CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _titleController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );
    _titleScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _titleController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );

    // 3. Subtitle + Slider (fade + slide)
    _subController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _subFade = CurvedAnimation(parent: _subController, curve: Curves.easeIn);
    _subSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _subController, curve: Curves.easeOutCubic),
    );

    // 4. Shimmer effect
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // 5. Pulsating glow for the button
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 6. Exit transition
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
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _subController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _titleController.dispose();
    _subController.dispose();
    _shimmerController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, _maxWidth - 62);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    if (_dragValue > _maxWidth - 100) {
      _completeSplash();
    } else {
      setState(() => _dragValue = 0.0);
    }
  }

  void _completeSplash() async {
    setState(() {
      _completed = true;
      _dragValue = _maxWidth - 62;
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
          // ── Background Image
          FadeTransition(
            opacity: _bgFade,
            child: Image.asset(
              'assets/images/main3ori.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Decorative Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // ── Main Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title reveal
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: ScaleTransition(
                      scale: _titleScale,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              final shimmerX =
                                  (_shimmerController.value * 2.5 - 0.75) *
                                      bounds.width;
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Color(0xFFCCFF00),
                                  Colors.white,
                                  Colors.white,
                                ],
                                stops: [
                                  0.0,
                                  (shimmerX / bounds.width).clamp(0.0, 1.0),
                                  ((shimmerX + 80) / bounds.width)
                                      .clamp(0.0, 1.0),
                                  ((shimmerX + 160) / bounds.width)
                                      .clamp(0.0, 1.0),
                                  1.0,
                                ],
                              ).createShader(bounds);
                            },
                            child: child!,
                          );
                        },
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
                          color: const Color(0xFFCCFF00).withOpacity(0.5),
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
                          color: const Color(0xFFCCFF00).withOpacity(0.5),
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
                      : Container(
                          width: _maxWidth,
                          height: 72,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 32),
                                  child: Text(
                                    'GET STARTED',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: _dragValue,
                                child: GestureDetector(
                                  onHorizontalDragUpdate: _onDragUpdate,
                                  onHorizontalDragEnd: _onDragEnd,
                                  child: AnimatedBuilder(
                                    animation: _glowController,
                                    builder: (context, child) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFCCFF00),
                                              Color(0xFFAABB00)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFCCFF00)
                                                  .withOpacity(0.3 +
                                                      0.2 *
                                                          _glowController
                                                              .value),
                                              blurRadius: 15 +
                                                  10 * _glowController.value,
                                              spreadRadius:
                                                  2 + 3 * _glowController.value,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.black87,
                                          size: 32,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
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
