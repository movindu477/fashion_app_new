import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'image': 'assets/images/main4.jpg',
      'title': 'Style\nNever\nStops',
      'description':
          'Elevate your unique fashion identity with AI-driven fabric analysis and trend insights.',
    },
    {
      'image': 'assets/images/main5.jpg',
      'title': 'AI\nPowered\nDesign',
      'description':
          'Revolutionize your wardrobe using state-of-the-art neural networks to analyze texture and color.',
    },
    {
      'image': 'assets/images/main6.jpg',
      'title': 'Your\nDigital\nWardrobe',
      'description':
          'Build and manage your personalized fashion collection entirely on your device with Texora.',
    },
  ];

  void _onNext() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        child: const LoginPage(),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. PAGE VIEW FOR BACKGROUNDS
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _onboardingData[index]['image']!,
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  // Content Area
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32.0, vertical: 40.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _onboardingData[index]['title']!,
                            key: ValueKey('title_$index'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 70,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: -2.0,
                            ),
                          )
                              .animate(key: ValueKey('title_anim_$index'))
                              .fadeIn(duration: 600.ms)
                              .slideX(begin: 0.2, end: 0),
                          const SizedBox(height: 20),
                          // Description
                          Text(
                            _onboardingData[index]['description']!,
                            key: ValueKey('desc_$index'),
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          )
                              .animate(key: ValueKey('desc_anim_$index'))
                              .fadeIn(delay: 200.ms, duration: 600.ms)
                              .slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 120), // Space for button
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. BOTTOM NAVIGATION (BUTTON & INDICATORS)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFFFF5200)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideX(begin: -0.2, end: 0),
                  ),
                  const SizedBox(height: 30),
                  // Primary Action Button (AS SEEN IN UI)
                  GestureDetector(
                    onTap: _onNext,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5200),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF5200).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPage == 0
                              ? "Explore Style"
                              : _currentPage == 1
                                  ? "Discover AI"
                                  : "Get Started",
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
