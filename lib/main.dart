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

  // ── Stage 2: title reveal (slide up + fade in)
  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  // ── Stage 3: subtitle + slider appear
  late AnimationController _subController;
  late Animation<double> _subFade;

  // ── Stage 4: shimmer sweep across the title
  late AnimationController _shimmerController;

  // ── Stage 5: exit flash on completion
  late AnimationController _exitController;
  late Animation<double> _exitFlash; // 0→1 white flash
  late Animation<double> _exitFade; // 1→0 screen fade out

  double _dragValue = 0.0;
  final double _maxWidth = 200.0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    FabricClassifierService().loadModel();

    // 1. Background fades in over 1.2s
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bgFade = CurvedAnimation(parent: _bgController, curve: Curves.easeIn);

    // 2. Title slides up + fades in (starts a bit after bg)
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleFade =
        CurvedAnimation(parent: _titleController, curve: Curves.easeOut);
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic));

    // 3. Subtitle + slider fade in
    _subController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _subFade = CurvedAnimation(parent: _subController, curve: Curves.easeIn);

    // 4. Shimmer sweeps continuously
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 5. Exit: brief white flash then fade out
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _exitFlash = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _exitFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // bg fade in
    await _bgController.forward();
    // title slide up (with short overlap)
    await Future.delayed(const Duration(milliseconds: 100));
    await _titleController.forward();
    // subtitle + slider ease in
    await Future.delayed(const Duration(milliseconds: 200));
    _subController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _titleController.dispose();
    _subController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, _maxWidth - 50);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    if (_dragValue > _maxWidth - 60) {
      _completeSplash();
    } else {
      setState(() => _dragValue = 0.0);
    }
  }

  void _completeSplash() async {
    setState(() {
      _completed = true;
      _dragValue = _maxWidth - 50;
    });

    // Play exit: white flash → full screen fade to black → navigate
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
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
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
          // ── 1. Background image fades in
          FadeTransition(
            opacity: _bgFade,
            child: Image.asset(
              'assets/images/main3.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── 2. Darkening overlay for contrast
          FadeTransition(
            opacity: _bgFade,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Center: title + subtitle
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title: slides up + fades, then shimmer effect
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            // Shimmer sweeps left → right
                            final shimmerX =
                                (_shimmerController.value * 2 - 0.5) *
                                    bounds.width;
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: const [
                                Colors.white,
                                Colors.white,
                                Color(0xFFF0FFD6), // soft green highlight
                                Colors.white,
                                Colors.white,
                              ],
                              stops: [
                                0.0,
                                (shimmerX / bounds.width).clamp(0.0, 1.0),
                                ((shimmerX + 60) / bounds.width)
                                    .clamp(0.0, 1.0),
                                ((shimmerX + 120) / bounds.width)
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
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 82,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Subtitle: fades in after title
                FadeTransition(
                  opacity: _subFade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Red accent line left
                      Container(
                        width: 22,
                        height: 1.5,
                        color: const Color(0xFFCCFF00),
                        margin: const EdgeInsets.only(right: 10),
                      ),
                      Text(
                        'AI FASHION DESIGN',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 6.5,
                        ),
                      ),
                      // Red accent line right
                      Container(
                        width: 22,
                        height: 1.5,
                        color: const Color(0xFFCCFF00),
                        margin: const EdgeInsets.only(left: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 4. Bottom slider
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _subFade,
              child: Center(
                child: _completed
                    ? const SizedBox()
                    : Container(
                        width: _maxWidth,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            const Positioned(
                              right: 22,
                              child: Text(
                                'Slide',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Positioned(
                              left: _dragValue + 5,
                              child: GestureDetector(
                                onHorizontalDragUpdate: _onDragUpdate,
                                onHorizontalDragEnd: _onDragEnd,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFF00),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFCCFF00)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // ── 5. Exit flash overlay (white → then dark)
          AnimatedBuilder(
            animation: _exitController,
            builder: (context, _) {
              if (_exitController.value == 0) return const SizedBox();
              return Stack(
                fit: StackFit.expand,
                children: [
                  // White flash
                  Opacity(
                    opacity: (_exitFlash.value * (1 - _exitFade.value))
                        .clamp(0.0, 1.0),
                    child: Container(color: Colors.white),
                  ),
                  // Black fade out
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
