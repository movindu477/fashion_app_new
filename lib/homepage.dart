import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'profile_page.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickalert/quickalert.dart'; // Added QuickAlert
import 'dart:typed_data'; // Added for Uint8List
import 'dart:async'; // Added for TimeoutException

import 'api_config.dart';

import 'fabric_library_page.dart';

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
            children: [
              const HomeView(), // 0: Home (Scan)
              const FabricLibraryPage(), // 1: Library (History)
              const Center(
                  child: Text(
                      "Activity Page Coming Soon")), // 2: Activity (Placeholder)
              ProfilePage(
                onBack: () => _onTabTapped(0),
              ), // 3: Profile (with Back callback)
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                        icon: Icons.history_edu_rounded,
                        label: "Library",
                        isActive: _currentIndex == 1,
                        onTap: () => _onTabTapped(1),
                      ),
                      _NavBarItem(
                        icon: Icons.notifications_none_rounded,
                        label: "Activity",
                        isActive: _currentIndex == 2,
                        onTap: () => _onTabTapped(2),
                      ),
                      _NavBarItem(
                        icon: Icons.person_outline_rounded,
                        label: "Profile",
                        isActive: _currentIndex == 3,
                        onTap: () => _onTabTapped(3),
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

class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  Uint8List? fabricImageBytes; // Changed from File
  String? fabricImagePath; // Added for Firestore
  bool _isUploading = false;
  List<List<int>> dominantColors = [];
  bool analysisCompleted = false;
  String? suggestedUse; // New: For analysis note

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

  Future<void> saveFabricAnalysis({
    required String imagePath,
    required List<List<int>> colors,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Convert colors to Map structure for better Firestore querying
    List<Map<String, int>> formattedColors = colors.map((c) {
      if (c.length >= 3) {
        return {
          'r': c[0],
          'g': c[1],
          'b': c[2],
        };
      }
      return {'r': 0, 'g': 0, 'b': 0}; // Fallback
    }).toList();

    await FirebaseFirestore.instance.collection('fabric_library').add({
      'userId': user.uid,
      'imagePath': imagePath,
      'dominantColors': formattedColors,
      'createdAt': Timestamp.now(),
      'analysisType': 'color-extraction',
    });
  }

  Future<void> uploadFabricImage() async {
    if (fabricImageBytes == null) return;
    setState(() {
      _isUploading = true;
      analysisCompleted = false;
      dominantColors = [];
    });

    try {
      print("📤 Sending request to ${ApiConfig.baseUrl}/upload-fabric");

      final uri = Uri.parse("${ApiConfig.baseUrl}/upload-fabric");
      var request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'fabric',
        fabricImageBytes!,
        filename: 'fabric.jpg',
      ));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 15));

      final responseBody = await streamedResponse.stream.bytesToString();

      print("📥 Response status: ${streamedResponse.statusCode}");
      print("📥 Response body: $responseBody");

      final decoded = jsonDecode(responseBody);

      if (decoded['status'] == 'success') {
        print("✅ Analysis success");
        if (decoded['analysis'] != null &&
            decoded['analysis']['dominant_colors'] != null) {
          final List<dynamic> colors = decoded['analysis']['dominant_colors'];
          setState(() {
            dominantColors = colors.map((c) {
              return (c as List).map((val) => (val as num).toInt()).toList();
            }).toList();
            analysisCompleted = true;
          });

          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            title: 'Analysis Complete',
            text: 'Fabric analyzed successfully!',
            onConfirmBtnTap: () {
              Navigator.of(context).pop(); // Close the alert
              // Smooth scroll to results after a short delay to ensure UI frame is ready
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_resultsKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _resultsKey.currentContext!,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOutQuart,
                    alignment:
                        0.1, // Align slightly below the very top (0.0 is top)
                  );
                }
              });
            },
          );

          // Save to Firestore (Existing method)
          _saveAnalysisToFirestore();

          // Save to Firestore (New method requested by User)
          if (fabricImagePath != null) {
            await saveFabricAnalysis(
              imagePath: fabricImagePath!,
              colors: dominantColors,
            );
          }
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.warning,
            title: 'Incomplete',
            text: 'No colors found in analysis',
          );
        }
      } else {
        print("⚠️ Backend returned partial/error: ${decoded['message']}");
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Analysis Failed',
          text: decoded['message'] ?? "Unknown error",
        );
      }
    } on TimeoutException {
      print("⏱️ TIMEOUT: No response from Node.js");
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Timeout',
        text: "Server took too long to respond. Please check your connection.",
      );
    } catch (e) {
      print("❌ Flutter exception: $e");
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Error',
        text: "Unexpected error: $e",
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 🔹 NEW: Save to Firestore

  bool _isSaving = false;
  bool _saveSuccess = false;

  Future<void> _saveAnalysisToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || fabricImageBytes == null || dominantColors.isEmpty)
      return;

    final firstColor = dominantColors[0];
    final brightness =
        (firstColor[0] * 299 + firstColor[1] * 587 + firstColor[2] * 114) /
            1000;
    final use =
        brightness > 128 ? "Casual / Summer Wear" : "Formal / Evening Wear";

    setState(() {
      suggestedUse = use;
      _isSaving = true;
      _saveSuccess = false;
    });

    try {
      print("💾 Saving analysis to big data (Base64 Mode)...");

      // Skip Storage Upload (User on free plan / constrained)
      // Convert image to Base64 String
      String base64Image = base64Encode(fabricImageBytes!);

      // Convert colors to Map structure to avoid "Nested arrays not supported" error
      List<Map<String, int>> formattedColors = dominantColors.map((c) {
        if (c.length >= 3) {
          return {
            'r': c[0],
            'g': c[1],
            'b': c[2],
          };
        }
        return {'r': 0, 'g': 0, 'b': 0};
      }).toList();

      // Save Metadata + Image String to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analyses')
          .add({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': base64Image, // Storing Base64 here instead of URL
        'isBase64': true, // Flag to help UI decode it
        'colors': formattedColors,
        'suggestedUse': use,
        'platform': ApiConfig.isEmulator ? "emulator" : "real_device",
        'device_ip': ApiConfig.baseUrl,
      });

      print("✅ Analysis Data (Base64) Saved to Firestore");
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccess = true;
        });
      }
    } catch (e) {
      print("⚠️ Failed to save analysis history: $e");
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccess = false;
        });

        // Use QuickAlert for Error
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

  // Helper to convert RGB list to Color
  Color _rgbToColor(List<int> rgb) {
    if (rgb.length < 3) return Colors.black;
    return Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);
  }

  // Helper to get hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
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
              height: fabricImageBytes != null
                  ? 270
                  : 220, // Increased height to prevent overflow
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

          // 3. Analysis Results Section (Modernized Summary)
          if (analysisCompleted && dominantColors.isNotEmpty) ...[
            const SizedBox(height: 35),

            // SUMMARY CARD
            Container(
              key: _resultsKey,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fabric Report",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isSaving
                              ? Colors.orange[50]
                              : (_saveSuccess
                                  ? Colors.green[50]
                                  : Colors.red[50]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSaving
                                ? Colors.orange[100]!
                                : (_saveSuccess
                                    ? Colors.green[100]!
                                    : Colors.red[100]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isSaving)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.orange),
                              )
                            else
                              Icon(
                                  _saveSuccess
                                      ? Icons.cloud_done
                                      : Icons.error_outline,
                                  size: 14,
                                  color:
                                      _saveSuccess ? Colors.green : Colors.red),
                            const SizedBox(width: 6),
                            Text(
                              _isSaving
                                  ? "Saving..."
                                  : (_saveSuccess ? "Saved" : "Failed"),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isSaving
                                    ? Colors.orange
                                    : (_saveSuccess
                                        ? Colors.green
                                        : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Detail Row 1: Date & Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        "Captured: ${DateTime.now().toString().split(' ')[0]}",
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Detail Row 2: Suggested Use
                  Row(
                    children: [
                      Icon(Icons.style_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        suggestedUse ?? "Analyzing...",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Detected Colors",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140, // Taller for modern look
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: dominantColors.length,
                itemBuilder: (context, index) {
                  final color = _rgbToColor(dominantColors[index]);
                  final hex = _colorToHex(color);
                  final isDark = ThemeData.estimateBrightnessForColor(color) ==
                      Brightness.dark;

                  return GestureDetector(
                    onTap: () {
                      // Copy to clipboard or show detail (simplified to snackbar here)
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.success,
                        title: 'Copied',
                        text: "Color $hex copied!",
                        confirmBtnColor: color,
                        autoCloseDuration: const Duration(seconds: 2),
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Shine effect
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.topRight,
                                  radius: 1.0,
                                  colors: [
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(24),
                                ),
                              ),
                            ),
                          ),

                          // Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (index == 0)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.star,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),

                              const Spacer(),

                              // Hex Pill
                              Container(
                                margin: const EdgeInsets.all(12),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withOpacity(0.2), // Glass feel
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  hex,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

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
