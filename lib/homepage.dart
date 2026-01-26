import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data'; // Added for Uint8List
import 'dart:io'; // Kept for Platform.isAndroid check

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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavBarItem(
                        icon: Icons.home_rounded,
                        label: "Home",
                        isActive: _currentIndex == 0,
                        onTap: () => _onTabTapped(0),
                      ),
                      _NavBarItem(
                        icon: Icons.grid_view_rounded,
                        label: "Explore",
                        isActive: _currentIndex == 1,
                        onTap: () => _onTabTapped(1),
                      ),
                      _NavBarItem(
                        icon: Icons.add_rounded,
                        label: "Create",
                        isActive: _currentIndex == 2,
                        onTap: () => _onTabTapped(2),
                      ),
                      _NavBarItem(
                        icon: Icons.notifications_none_rounded,
                        label: "Activity",
                        isActive: _currentIndex == 3,
                        onTap: () => _onTabTapped(3),
                      ),
                      _NavBarItem(
                        icon: Icons.person_outline_rounded,
                        label: "Profile",
                        isActive: _currentIndex == 4,
                        onTap: () => _onTabTapped(4),
                      ),
                    ],
                  ),
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
          color: isActive ? const Color(0xFFFF5200) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white54,
              size: 26,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? fabricImageBytes; // Changed from File
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
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes(); // Read image as bytes
      setState(() {
        fabricImageBytes = bytes; // Store bytes
      });
      // Auto upload/analyze could happen here if desired, but user kept separate
    }
  }

  Future<void> uploadFabricImage() async {
    if (fabricImageBytes == null) return; // Check for bytes
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

      // Use fromBytes instead of fromPath
      request.files.add(http.MultipartFile.fromBytes(
        'fabric',
        fabricImageBytes!,
        filename: 'fabric.jpg', // Provide a filename
      ));

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

                      // Analyze Button (Visible when image is captured)
                      if (fabricImageBytes != null) // Check for bytes
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : uploadFabricImage,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.analytics_outlined,
                                    size: 16),
                            label: Text(
                                _isUploading ? "Analyzing..." : "Analyze Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // 3D Character/Image Placeholder (Right side)
                  // Using Scan Icon/Image if captured
                  Positioned(
                    right: -20,
                    bottom: -20,
                    top: 20,
                    child: fabricImageBytes != null // Check for bytes
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              // Use Image.memory
                              fabricImageBytes!,
                              width:
                                  120, // Reduced width to make room for button
                              height: 120,
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
