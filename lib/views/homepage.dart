import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
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
                          color: const Color(0xFFFF5200), width: 1.5),
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
                  colors: [Color(0xFFFF5200), Color(0xFFE64A19)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5200).withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: -10,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Design Your\nFuture Today",
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Transform any fabric into a professional fashion silhouette with our AI engine.",
                    style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 35),
            _buildSectionHeader("Quick Actions", null),
            const SizedBox(height: 16),
            Row(
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
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            Row(
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
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 40),
            _buildSectionHeader("Recent Analysis", "View All",
                onActionTap: () => context
                    .findAncestorStateOfType<_HomePageState>()
                    ?._onTabTapped(1)),
            const SizedBox(height: 16),
            _buildRecentScansList(),
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
                      color: Color(0xFFFF5200), size: 22),
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
                              color: const Color(0xFFFF5200)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "NEXT GEN",
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFF5200),
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
                color: const Color(0xFFFF5200),
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScansList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: Column(
              children: [
                const Icon(Icons.history_toggle_off_rounded,
                    color: Colors.white24, size: 40),
                const SizedBox(height: 12),
                Text(
                  "No recent scans yet",
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] ?? '';
            final fabricType = data['fabricType'] ?? 'Unknown';
            final timestamp = data['timestamp'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fabricType,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timestamp != null
                              ? "${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}"
                              : "Just now",
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white24),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
