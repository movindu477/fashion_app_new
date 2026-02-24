import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'fabric_library_page.dart';
import 'scan_page.dart';
import 'ai_design_page.dart';
import 'profile_page.dart';
import '../widgets/custom_bottom_nav.dart';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _pageController;

  // Shared state for AI Design
  String? _currentConcept;
  List<Map<String, int>>? _currentColors;
  Uint8List? _currentFabricImage;
  String? _currentStyle;
  String? _currentGender;
  String? _currentGarment;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              HomeView(onHistoryTap: () => _onTabTapped(1)),
              const FabricLibraryPage(),
              ScanPage(
                onHistoryTap: () => _onTabTapped(1),
                onConceptGenerated:
                    (concept, colors, image, style, gender, garment) {
                  setState(() {
                    _currentConcept = concept;
                    _currentColors = colors;
                    _currentFabricImage = image;
                    _currentStyle = style;
                    _currentGender = gender;
                    _currentGarment = garment;
                  });
                },
              ),
              AiDesignPage(
                designConcept: _currentConcept,
                dominantColors: _currentColors,
                fabricImage: _currentFabricImage,
                selectedStyle: _currentStyle,
                selectedGender: _currentGender,
                selectedGarment: _currentGarment,
              ),
              ProfilePage(
                onBack: () => _onTabTapped(0),
              ),
            ],
          ),
          Positioned(
            bottom: 25,
            left: 25,
            right: 25,
            child: CustomBottomNavBar(
              currentIndex: _currentIndex,
              onTabTapped: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  const HomeView({Key? key, this.onHistoryTap}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin {
  User? _user;
  Map<String, dynamic>? _userData;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _user = user;
        });
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted) {
          setState(() {
            _user = user;
            _userData = doc.data();
          });
        }
      } catch (e) {
        print("Error fetching user: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String displayName = _userData?['name']?.toString() ??
        _user?.displayName ??
        _user?.email?.split('@')[0] ??
        "Arousing";

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 45),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Navigate to profile tab in HomePage
                    final homepageState =
                        context.findAncestorStateOfType<_HomePageState>();
                    if (homepageState != null) {
                      homepageState._onTabTapped(3);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFCCFF00), width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1A1A1A),
                      backgroundImage: _userData?['photoUrl'] != null
                          ? NetworkImage(_userData?['photoUrl'])
                          : null,
                      child: _userData?['photoUrl'] == null
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 20)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello,",
                      style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 13, height: 1.2),
                    ),
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1A3A), Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: -10,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Discover Your\nUnique Style",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Switch to the Scan tab to start analyzing fabrics and generating AI designs.",
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 30),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Color(0xFFCCFF00), size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Chat with your AI Stylist...",
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 40),
            _buildSectionHeader("AI Style Inspiration", "Explore")
                .animate()
                .fadeIn(delay: 800.ms)
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/main7.jpg', fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Trending Textures",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Discover how AI redefines summer collections",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 30),
            _buildSectionHeader("Fashion Forecast", "View All")
                .animate()
                .fadeIn(delay: 1000.ms)
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFF00)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "NEXT GEN",
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFCCFF00),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Sustain Style",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "Eco-friendly fabric analysis",
                            style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      child: Image.asset('assets/images/main8.jpg',
                          fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? action,
      {VoidCallback? onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action,
              style: GoogleFonts.poppins(
                color: const Color(0xFFCCFF00),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
