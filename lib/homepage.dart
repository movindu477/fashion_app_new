import 'dart:io';
import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    // pageController is disposed
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Main Page Content
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeView(),
              Center(
                  child: Text("EXPLORE",
                      style: TextStyle(color: Colors.black, fontSize: 20))),
              HomeView(), // Scan/Create Tab
              Center(
                  child: Text("ACTIVITY",
                      style: TextStyle(color: Colors.black, fontSize: 20))),
              ProfilePage(),
            ],
          ),

          // 2. Floating Bottom Navigation Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 30, // Elevated slightly more
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              child: Stack(
                children: [
                  // Active Indicator (Orange Circle)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double containerWidth = constraints.maxWidth;
                      return AnimatedAlign(
                        alignment: Alignment(
                            _getAlignmentX(_currentIndex, containerWidth), 0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5200), // Vibrant Orange
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),

                  // Icons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                          child: Center(
                              child: _NavBarItem(
                                  icon: Icons.home_rounded,
                                  isActive: _currentIndex == 0,
                                  onTap: () => _onTabTapped(0)))),
                      Expanded(
                          child: Center(
                              child: _NavBarItem(
                                  icon: Icons.grid_view_rounded,
                                  isActive: _currentIndex == 1,
                                  onTap: () => _onTabTapped(1)))),
                      Expanded(
                          child: Center(
                              child: _NavBarItem(
                                  icon: Icons.add_rounded,
                                  isActive: _currentIndex == 2,
                                  isLarge: true,
                                  onTap: () => _onTabTapped(2)))),
                      Expanded(
                          child: Center(
                              child: _NavBarItem(
                                  icon: Icons.notifications_none_rounded,
                                  isActive: _currentIndex == 3,
                                  onTap: () => _onTabTapped(3)))),
                      Expanded(
                          child: Center(
                              child: _NavBarItem(
                                  icon: Icons.person_outline_rounded,
                                  isActive: _currentIndex == 4,
                                  onTap: () => _onTabTapped(4)))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Precise Dynamic Alignment
  // Accounts for the button width (55) to ensure centers match perfectly
  double _getAlignmentX(int index, double containerWidth) {
    double range = 2.0; // From -1 to 1
    double step = range / 5; // 0.4 per item
    // Center positions in -1..1 scale: -0.8, -0.4, 0.0, 0.4, 0.8
    // Formula: -1 + (step/2) + (index * step)
    double targetBase = -1.0 + (step / 2) + (index * step);

    // Correction factor for indicator size
    // Align x=1 puts right edge at right edge. We want center at center.
    // X_corrected = X_base * (ParentWidth / (ParentWidth - ChildWidth))
    double buttonWidth = 55.0;
    if (containerWidth <= buttonWidth) return 0.0; // Safety

    return targetBase * (containerWidth / (containerWidth - buttonWidth));
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isLarge;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 70,
        width: 60,
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white38,
          size: isLarge ? 32 : 26,
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
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ImagePicker _picker = ImagePicker();
  File? fabricImage;
  bool _isUploading = false;
  List<List<int>> dominantColors = [];
  bool analysisCompleted = false;

  // User Data & Video
  User? _user;
  Map<String, dynamic>? _userData;
  late VideoPlayerController _videoController;

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
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        fabricImage = File(image.path);
      });
      // Auto upload/analyze could happen here if desired, but user kept separate
    }
  }

  Future<void> uploadFabricImage() async {
    if (fabricImage == null) return;
    setState(() {
      _isUploading = true;
      analysisCompleted = false;
      dominantColors = [];
    });

    try {
      final String baseUrl =
          Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-fabric'));
      request.files
          .add(await http.MultipartFile.fromPath('fabric', fabricImage!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded['analysis'] != null &&
              decoded['analysis']['dominant_colors'] != null) {
            final colors = decoded['analysis']['dominant_colors'];
            setState(() {
              dominantColors =
                  List<List<int>>.from(colors.map((c) => List<int>.from(c)));
              analysisCompleted = true;
            });
            _showSnackBar("Fabric analyzed!", Colors.green);
          }
        } catch (e) {
          _showSnackBar("Parsing error", Colors.orange);
        }
      } else {
        _showSnackBar("Upload failed", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection Error", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 60, 12, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Video Header Section
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video Background
                  _videoController.value.isInitialized
                      ? VideoPlayer(_videoController)
                      : Container(color: Colors.black),
                  // Dark Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  // Text Content
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Hello",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(
                          _userData?['name']?.toUpperCase() ??
                              _user?.displayName?.toUpperCase() ??
                              _user?.email?.split('@')[0].toUpperCase() ??
                              "DESIGNER",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Welcome back to your studio.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // 2. Hero Card (Fabric Analysis)
          GestureDetector(
            onTap: captureFabricImage,
            child: Container(
              width: double.infinity,
              height: 220,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E2E2E), Color(0xFF1A1A1A)], // Dark card
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Fabric\nAnalysis",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isUploading
                            ? "Analyzing..."
                            : analysisCompleted
                                ? "Scan Complete!"
                                : "Scan to analyze texture",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),

                      // Avatars or Status
                      Row(
                        children: [
                          _buildMiniAvatar(Colors.purple, "A"),
                          Transform.translate(
                              offset: const Offset(-10, 0),
                              child: _buildMiniAvatar(Colors.blue, "B")),
                          Transform.translate(
                              offset: const Offset(-20, 0),
                              child: _buildMiniAvatar(Colors.orange, "C")),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ],
                  ),

                  // 3D Character/Image Placeholder (Right side)
                  // Using Scan Icon/Image if captured
                  Positioned(
                    right: -20,
                    bottom: -20,
                    top: 20,
                    child: fabricImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              fabricImage!,
                              width: 150,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.document_scanner_outlined,
                            size: 140,
                            color: Colors.white.withOpacity(0.1),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Search & Quick Actions Removed

          const SizedBox(height: 30),

          // 5. AI Styling Grid
          const Text(
            "AI Styling",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Start AI Styling
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Start AI Styling",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Add 0/5",
                              style: TextStyle(
                                  color: Colors.black38, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.black, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // History
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "History",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("10/5",
                              style: TextStyle(
                                  color: Colors.black38, fontSize: 12)),
                          const Icon(Icons.history_toggle_off,
                              color: Colors.black38, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold))),
    );
  }
}
