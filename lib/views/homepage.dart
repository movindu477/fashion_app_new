import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fabric_library_page.dart';
import 'scan_page.dart';
import 'profile_page.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/tutorial_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _pageController;
  bool _showTutorial = false;
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;

    if (!hasSeenTutorial) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get name from Firestore first
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          _userName = doc.data()?['name'] ??
              user.displayName ??
              user.email?.split('@')[0] ??
              "New Designer";
          _showTutorial = true;
        });
      }
    }
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
    setState(() {
      _showTutorial = false;
    });
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
                  // State is now internal to ScanPage
                },
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
          if (_showTutorial)
            TutorialOverlay(
              userName: _userName,
              onComplete: _completeTutorial,
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
        "Designer";

    final currentTime = DateTime.now();
    String greeting;
    if (currentTime.hour < 12) {
      greeting = "Good morning";
    } else if (currentTime.hour < 17) {
      greeting = "Good afternoon";
    } else {
      greeting = "Good evening";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        // Padding moved from top-level to children individual sections
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern Header Section with Background Image
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  // 1. Background Image via Profile.webp
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/profile.webp',
                          fit: BoxFit.cover,
                          height: 260,
                          width: double.infinity,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Header Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          // Profile + Greeting
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final homepageState =
                                      context.findAncestorStateOfType<
                                          _HomePageState>();
                                  if (homepageState != null) {
                                    homepageState._onTabTapped(3);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFFF5200),
                                        width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    backgroundImage: _userData?['photoUrl'] !=
                                            null
                                        ? NetworkImage(_userData?['photoUrl'])
                                        : null,
                                    child: _userData?['photoUrl'] == null
                                        ? const Icon(Icons.person,
                                            color: Colors.white54, size: 26)
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hey $displayName,",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 200.ms)
                                      .slideX(begin: -0.1, end: 0),
                                  Text(
                                    greeting,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w400,
                                      height: 1.0,
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 400.ms)
                                      .slideX(begin: -0.1, end: 0),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Re-apply padding for rest of the content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  RepaintBoundary(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5200), Color(0xFFE64A19)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Design Your\nFuture Today",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Transform any fabric into a professional fashion silhouette with our AI engine.",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(),
                  ),
                  const SizedBox(height: 35),
                  _buildSectionHeader("Quick Actions", null),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: Row(
                      children: [
                        _buildQuickAction(
                          "New Scan",
                          Icons.camera_alt_rounded,
                          const Color(0xFFFF5200),
                          () => context
                              .findAncestorStateOfType<_HomePageState>()
                              ?._onTabTapped(2),
                        ),
                        const SizedBox(width: 16),
                        _buildQuickAction(
                          "My Library",
                          Icons.collections_bookmark_rounded,
                          Colors.blueAccent,
                          () => context
                              .findAncestorStateOfType<_HomePageState>()
                              ?._onTabTapped(1),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: Row(
                      children: [
                        _buildQuickAction(
                          "View Profile",
                          Icons.person_rounded,
                          Colors.orangeAccent,
                          () => context
                              .findAncestorStateOfType<_HomePageState>()
                              ?._onTabTapped(3),
                        ),
                        const SizedBox(width: 16),
                        _buildQuickAction(
                          "Help Center",
                          Icons.help_outline_rounded,
                          Colors.orangeAccent,
                          () {},
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                  const SizedBox(height: 45),
                  _buildSectionHeader("AI Style Inspiration", "Explore")
                      .animate()
                      .fadeIn(delay: 800.ms)
                      .slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: Container(
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
                            Image.asset(
                              'assets/images/main7.jpg',
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                            ),
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
                                  const Text(
                                    "Trending Textures",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Text(
                                    "Discover how AI redefines summer collections",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w400,
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
                    )
                        .animate()
                        .fadeIn(delay: 800.ms)
                        .slideY(begin: 0.2, end: 0),
                  ),
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
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
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
                                    color: const Color(0xFFFF5200)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "NEXT GEN",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: const Color(0xFFFF5200),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Sustain Style",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  "Eco-friendly fabric analysis",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w400,
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
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: const Color(0xFFFF5200),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickAction(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 135, // Slightly taller for more breathing room
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A1A),
                color.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle glass shine
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, 
                        color: Colors.white.withValues(alpha: 0.15), size: 14),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1, 1),
      curve: Curves.easeOutBack,
    );
  }
}
