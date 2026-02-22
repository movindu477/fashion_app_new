import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_page.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickalert/quickalert.dart';
import 'dart:typed_data';
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'fabric_library_page.dart';
import 'services/color_analysis_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late PageController _pageController;

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
          // 1. Page content — jumpToPage for instant no-jank switching
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              HomeView(onHistoryTap: () => _onTabTapped(1)),
              const FabricLibraryPage(),
              const Center(
                  child:
                      Text('Scan Page', style: TextStyle(color: Colors.white))),
              ProfilePage(
                onBack: () => _onTabTapped(0),
              ),
            ],
          ),

          // 2. Floating Bottom Navigation Bar
          Positioned(
            bottom: 25,
            left: 25,
            right: 25,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.97),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavBarItem(
                      icon: Icons.home_filled,
                      label: 'Home',
                      isActive: _currentIndex == 0,
                      onTap: () => _onTabTapped(0),
                    ),
                    _NavBarItem(
                      icon: Icons.folder_open_rounded,
                      label: 'Library',
                      isActive: _currentIndex == 1,
                      onTap: () => _onTabTapped(1),
                    ),
                    _NavBarItem(
                      icon: Icons.style_outlined,
                      label: 'Scan',
                      isActive: _currentIndex == 2,
                      onTap: () => _onTabTapped(2),
                    ),
                    _NavBarItem(
                      icon: Icons.person_3_outlined,
                      label: 'Profile',
                      isActive: _currentIndex == 3,
                      onTap: () => _onTabTapped(3),
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

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        padding:
            EdgeInsets.symmetric(horizontal: isActive ? 16 : 8, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFCCFF00) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.black : Colors.white54,
              size: 26,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =================================================================
//                   HOME VIEW (Original Logic Refined)
// =================================================================

// =================================================================
//                   HOME VIEW (Redesigned)
// =================================================================

class HomeView extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  const HomeView({Key? key, this.onHistoryTap}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? fabricImageBytes;
  String? fabricImagePath;
  bool _isAnalyzing = false;
  List<Map<String, int>> dominantColors = [];
  bool analysisCompleted = false;
  String? suggestedUse;

  // User Data & Video
  User? _user;
  Map<String, dynamic>? _userData;
  late VideoPlayerController _videoController;

  // Key for auto-scrolling to results
  final GlobalKey _resultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    // Using an existing asset as placeholder since home1.mp4 is missing
    _videoController = VideoPlayerController.asset('assets/images/home1.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 1. FAST UPDATE: Set user immediately to show displayName/email
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

  Future<void> captureFabricImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50, // Reduced from 85 to save memory
      maxWidth: 1024, // Resize large images
    );

    if (image != null) {
      final bytes = await image.readAsBytes(); // Read image as bytes
      setState(() {
        fabricImageBytes = bytes; // Store bytes
        fabricImagePath = image.path;
      });
      // Auto upload/analyze could happen here if desired, but user kept separate
    }
  }

  Future<void> analyzeFabricLocally() async {
    if (fabricImagePath == null) return;

    setState(() {
      _isAnalyzing = true;
      analysisCompleted = false;
      dominantColors = [];
    });

    try {
      debugPrint("🚀 [ON-DEVICE] Starting color extraction...");
      debugPrint("📸 Image Path: $fabricImagePath");

      // Perform color extraction
      final colors =
          await ColorAnalysisService.getDominantColors(fabricImagePath!);

      if (colors.isNotEmpty) {
        debugPrint(
            "✅ [ON-DEVICE] Extraction successful: ${colors.length} colors found");
        setState(() {
          dominantColors = colors;
          analysisCompleted = true;

          // Calculate suggested use based on the first dominant color
          final firstColor = colors[0];
          final brightness = (firstColor['r']! * 299 +
                  firstColor['g']! * 587 +
                  firstColor['b']! * 114) /
              1000;
          suggestedUse = brightness > 128
              ? "Casual / Summer Wear"
              : "Formal / Evening Wear";
        });

        if (mounted) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Analysis Complete',
            text: 'Fabric analyzed locally on your device!',
            onConfirmBtnTap: () {
              Navigator.of(context).pop();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_resultsKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _resultsKey.currentContext!,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOutQuart,
                    alignment: 0.1,
                  );
                }
              });
            },
          );
        }

        // Save metadata to Firestore
        await _saveAnalysisToFirestore();
      } else {
        debugPrint("⚠️ [ON-DEVICE] No colors detected");
        if (mounted) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.warning,
            title: 'Incomplete',
            text: 'No colors found in analysis',
          );
        }
      }
    } catch (e) {
      debugPrint("❌ [ON-DEVICE] Analysis error: $e");
      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: "Local analysis failed: $e",
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  bool _saveSuccess = false;

  Future<void> _saveAnalysisToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || dominantColors.isEmpty) return;

    setState(() {
      _saveSuccess = false;
    });

    try {
      print("💾 Saving analysis metadata to Firestore...");

      // Save Metadata to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analyses')
          .add({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'imagePath': fabricImagePath,
        'dominantColors': dominantColors,
        'suggestedUse': suggestedUse,
        'analysisType': 'on-device-color-extraction',
        'createdAt': Timestamp.now(),
      });

      print("✅ Analysis Metadata Saved to Firestore");
      if (mounted) {
        setState(() {
          _saveSuccess = true;
        });
      }
    } catch (e) {
      print("⚠️ Failed to save analysis history: $e");
      if (mounted) {
        setState(() {
          _saveSuccess = false;
        });

        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Save Failed',
          text: 'Could not save to library: $e',
        );
      }
    }
  }

  // Removing _showSnackBar as we use QuickAlert now (or just inline it)

  // Helper to convert RGB map to Color
  Color _rgbToColor(Map<String, int> rgb) {
    if (rgb['r'] == null || rgb['g'] == null || rgb['b'] == null) {
      return Colors.black;
    }
    return Color.fromRGBO(rgb['r']!, rgb['g']!, rgb['b']!, 1.0);
  }

  // Helper to get hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
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
            // HEADER BAR
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (c) => const ProfilePage())),
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

            // MAIN FEATURE CARD (DAILY CHALLENGE STYLE)
            GestureDetector(
              onTap: captureFabricImage,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C1A3A), Color(0xFF1A1A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 40,
                      spreadRadius: -10,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _videoController.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController.value.size.width,
                                  height: _videoController.value.size.height,
                                  child: VideoPlayer(_videoController),
                                ),
                              )
                            : Container(color: Colors.black),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                      // Uploaded fabric image preview (bottom-right) - Rendered behind button now
                      if (fabricImageBytes != null)
                        Positioned(
                          right: -10,
                          bottom: -20,
                          child: Hero(
                            tag: 'scan_result',
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                image: DecorationImage(
                                  image: MemoryImage(fabricImageBytes!),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 30,
                                  )
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 600.ms)
                                .slideY(begin: 0.2, end: 0),
                          ),
                        ),
                      // Logo (bottom-right when no fabric image)
                      if (fabricImageBytes == null)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Opacity(
                            opacity: 0.85,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: 55,
                                width: 55,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Fashion\nIntelligence",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                height: 0.9,
                                letterSpacing: -1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 600.ms)
                                .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 12),
                            const Spacer(),
                            Row(
                              children: [
                                if (_isAnalyzing)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                else ...[
                                  _buildMiniStackAvatars(),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ],
                                const Spacer(),
                                if (fabricImageBytes != null &&
                                    !analysisCompleted)
                                  ElevatedButton(
                                    onPressed: _isAnalyzing
                                        ? null
                                        : analyzeFabricLocally,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 8,
                                      shadowColor:
                                          Colors.white.withOpacity(0.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    child: Text(
                                      "Analyze Now",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ).animate().fadeIn(duration: 300.ms).scale(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // AI PROMPT BAR
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFCCFF00), size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Ask away! I'm your stylist",
                      style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_none_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),

            const SizedBox(height: 30),

            // NEW SECTION: CAPTURED IMAGE PREVIEW (Visible after capture)
            if (fabricImageBytes != null) ...[
              _buildSectionHeader("Captured Fabric", "Clear", onActionTap: () {
                setState(() {
                  fabricImageBytes = null;
                  fabricImagePath = null;
                  analysisCompleted = false;
                  dominantColors = [];
                  suggestedUse = null;
                });
              }).animate().fadeIn().slideX(begin: -0.1, end: 0),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: captureFabricImage, // Allow re-capture by tapping
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: const Color(0xFFCCFF00).withOpacity(0.3),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCCFF00).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: -5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(fabricImageBytes!, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        if (!analysisCompleted && !_isAnalyzing)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCCFF00),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Ready to Analyze",
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              ),
              const SizedBox(height: 30),
            ],

            const SizedBox(height: 30),

            // SECTION: AI STYLING
            _buildSectionHeader("AI Styling", null)
                .animate()
                .fadeIn(delay: 600.ms)
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  _buildActionCard(
                    "Start AI Styling",
                    "Add 0/5",
                    Icons.add_circle_outline_rounded,
                    onTap: captureFabricImage,
                  ),
                  const SizedBox(width: 16),
                  _buildActionCard(
                    "History",
                    "10/5",
                    Icons.history_toggle_off_rounded,
                    onTap: widget.onHistoryTap,
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 700.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
            const SizedBox(height: 30),

            // SECTION: TRENDING / INNOVATIONS (ANALYSIS RESULTS)
            if (analysisCompleted && dominantColors.isNotEmpty) ...[
              _buildSectionHeader("Analysis Result", "Details"),
              const SizedBox(height: 16),
              Container(
                key: _resultsKey,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFFCCFF00).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCCFF00).withOpacity(0.05),
                      blurRadius: 30,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: MemoryImage(fabricImageBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestedUse ?? "Analyzed Fabric",
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              Row(
                                children: [
                                  Text(
                                    "AI Style Intelligence",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                  if (_saveSuccess) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified_rounded,
                                        color: Color(0xFFCCFF00), size: 14),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: dominantColors.take(4).map((rgb) {
                        final color = _rgbToColor(rgb);
                        return Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _colorToHex(color).substring(1),
                              style: TextStyle(
                                  color: color.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 40),
            ],

            // NEW SECTION: STYLE INSPIRATION (main7.jpg)
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
                    color: Colors.black.withOpacity(0.3),
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
                            Colors.black.withOpacity(0.8),
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

            // NEW SECTION: FASHION FORECAST (main8.jpg)
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
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                              color: const Color(0xFFCCFF00).withOpacity(0.2),
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

            const SizedBox(height: 100), // Bottom padding for navbar
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

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF151515),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFF00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFCCFF00), size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStackAvatars() {
    return SizedBox(
      width: 60,
      height: 24,
      child: Stack(
        children: [
          Positioned(left: 0, child: _buildMiniAvatar(Colors.purple, "A")),
          Positioned(left: 14, child: _buildMiniAvatar(Colors.blue, "B")),
          Positioned(
              left: 28, child: _buildMiniAvatar(const Color(0xFFCCFF00), "C")),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(Color color, String text) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
