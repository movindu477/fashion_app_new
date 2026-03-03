import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quickalert/quickalert.dart';
import '../services/color_analysis_service.dart';
import '../services/gemini_service.dart';
import '../services/fabric_classifier_service.dart';
import '../services/stability_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class ScanPage extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  final Function(
          String, List<Map<String, int>>, Uint8List, String, String, String)?
      onConceptGenerated;
  const ScanPage({super.key, this.onHistoryTap, this.onConceptGenerated});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  Uint8List? fabricImageBytes;
  String? fabricImagePath;
  bool _isAnalyzing = false;
  List<Map<String, int>> dominantColors = [];
  bool analysisCompleted = false;
  String? suggestedUse;
  FabricClassificationResult? _classificationResult;

  // Stability AI integration
  final StabilityService _stabilityService = StabilityService();
  Uint8List? _generatedSketch;
  bool _isGeneratingSketch = false;
  bool _isSavingSketch = false;
  final GlobalKey _sketchSectionKey = GlobalKey();

  // Video Controller for background
  late VideoPlayerController _videoController;
  bool _isGeneratingDesign = false;
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _promptController = TextEditingController();
  String _selectedStyle = "Casual";
  final List<String> _designStyles = [
    "Casual",
    "Formal",
    "Streetwear",
    "Evening Wear",
    "Traditional",
    "Avant-Garde",
    "Sportswear"
  ];

  String _selectedGender = "Unisex";
  final List<String> _genderOptions = ["Men", "Women", "Unisex"];

  String _selectedOccasion = "Casual";
  final List<String> _occasionOptions = [
    "Casual",
    "Formal",
    "Party",
    "Work",
    "Outdoor"
  ];

  String _selectedGarment = "Dress";
  final List<String> _garmentOptions = [
    "Top",
    "Bottom",
    "Dress",
    "Outerwear",
    "Accessory"
  ];

  final GlobalKey _resultsKey = GlobalKey();
  final GlobalKey _designResultKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // Generated Result state
  String? _generatedDesignConcept;
  bool _hasResult = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoController =
        VideoPlayerController.asset('assets/videos/fabric_bg.mp4')
          ..initialize().then((_) {
            setState(() {});
            _videoController.setLooping(true);
            _videoController.play();
          });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stabilityService.syncBalanceFromApi();
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Select Image Source",
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Capturing fabric texture directly works best",
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildSourceCard(
                    "Camera",
                    Icons.camera_rounded,
                    () {
                      Navigator.pop(context);
                      captureFabricImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceCard(
                    "Gallery",
                    Icons.photo_library_rounded,
                    () {
                      Navigator.pop(context);
                      captureFabricImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF9333EA), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> captureFabricImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      // Crop the image to focus on fabric texture
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Fabric Texture',
            toolbarColor: const Color(0xFF1A1A1A),
            toolbarWidgetColor: const Color(0xFF9333EA),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
            activeControlsWidgetColor: const Color(0xFF9333EA),
          ),
          IOSUiSettings(
            title: 'Crop Fabric Texture',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        final bytes = await File(croppedFile.path).readAsBytes();
        setState(() {
          fabricImageBytes = bytes;
          fabricImagePath = croppedFile.path;
          analysisCompleted = false;
          dominantColors = [];
        });
      }
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
      // 1. ML Fabric Classification Check
      final result =
          await FabricClassifierService().classify(File(fabricImagePath!));

      if (result.score > 0.7) {
        // Definitely not fabric
        if (mounted) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Material Not Recognized',
            text:
                'This looks like a ${result.label} (${(result.confidence * 100).toStringAsFixed(0)}% confidence). Please capture a textile or fabric surface.',
          );
        }
        setState(() => _isAnalyzing = false);
        return;
      } else if (result.score >= 0.3) {
        // Uncertain material
        if (mounted) {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.warning,
            title: 'Uncertain Material',
            text:
                'We are not sure if this is fabric (Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%). Please try again with better lighting or a closer shot.',
          );
        }
        setState(() => _isAnalyzing = false);
        return;
      }

      // If we reach here, prediction < 0.3 (Strong Fabric Confidence)
      print(
          "✅ High confidence fabric detected: ${(result.confidence * 100).toStringAsFixed(2)}%");

      setState(() {
        _classificationResult = result;
      });

      // 2. Color Analysis
      final colors =
          await ColorAnalysisService.getDominantColors(fabricImagePath!);

      if (colors.isNotEmpty) {
        setState(() {
          dominantColors = colors;
          analysisCompleted = true;
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
          _updateAutoPrompt(); // Auto-write to prompt box after analysis
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
        await _saveAnalysisToFirestore();
      }
    } catch (e) {
      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: "Local analysis failed: $e",
        );
      }
    } finally {
      if (mounted) {
        // Artificial delay for smooth animation
        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _saveAnalysisToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || fabricImagePath == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scanned_fabrics')
          .add({
        'imagePath': fabricImagePath,
        'dominantColors': dominantColors,
        'suggestedUse': suggestedUse,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving to Firestore: $e");
    }
  }

  Future<void> _handleGenerateDesign() async {
    if (fabricImageBytes == null || dominantColors.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'Missing Data',
        text: 'Please scan and analyze fabric first!',
      );
      return;
    }

    setState(() => _isGeneratingDesign = true);

    try {
      final response = await _geminiService.generateDesign(
        colors: dominantColors,
        style: _selectedStyle,
        userPrompt: _promptController.text,
        targetGender: _selectedGender,
        occasion: _selectedOccasion,
        garmentType: _selectedGarment,
      );

      if (mounted) {
        setState(() {
          _generatedDesignConcept = response;
          _hasResult = true;
        });

        // Trigger callback to shared state in HomePage
        if (widget.onConceptGenerated != null &&
            _generatedDesignConcept != null &&
            fabricImageBytes != null) {
          widget.onConceptGenerated!(
            _generatedDesignConcept!,
            dominantColors,
            fabricImageBytes!,
            _selectedStyle,
            _selectedGender,
            _selectedGarment,
          );
        }

        // Smooth scroll to the AI Sketch section
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_sketchSectionKey.currentContext != null) {
            Scrollable.ensureVisible(
              _sketchSectionKey.currentContext!,
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOutQuart,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Design Failed',
          text: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDesign = false);
    }
  }

  String _getPureDesignText(String text) {
    return text.trim();
  }

  void _showFullScreenImage(Uint8List imageBytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Close button
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom hint
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Pinch to zoom · Tap × to close",
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateSketch() async {
    if (_generatedDesignConcept == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'No Concept',
        text: 'Please generate a design concept first!',
      );
      return;
    }

    setState(() => _isGeneratingSketch = true);

    try {
      final sketch = await _stabilityService.generateFashionSketch(
        _generatedDesignConcept!,
        targetGender: _selectedGender,
        colors: dominantColors,
      );
      if (mounted) {
        setState(() {
          _generatedSketch = sketch;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("CREDITS_EXHAUSTED")) {
          _showTopUpDialog();
        } else {
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Sketch Failed',
            text: e.toString(),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSketch = false);
    }
  }

  void _showTopUpDialog() {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: 'Top Up Required',
      text: 'You need more credits to generate a professional sketch.',
      confirmBtnText: 'Top Up Now',
      onConfirmBtnTap: () async {
        final url = Uri.parse('https://stability.ai/generate');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      },
    );
  }

  Widget _buildCreditsBadge() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('system')
          .snapshots(),
      builder: (context, snapshot) {
        int credits = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          credits = snapshot.data!.get('image_credits') ?? 0;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF9333EA).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF9333EA).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded,
                  color: Color(0xFF9333EA), size: 14),
              const SizedBox(width: 4),
              Text(
                "$credits Credits",
                style: GoogleFonts.outfit(
                  color: const Color(0xFF9333EA),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveSketchToLibrary() async {
    if (_generatedSketch == null) return;

    setState(() => _isSavingSketch = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Upload sketch image to Firebase Storage
      final fileName =
          'sketches/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putData(
        _generatedSketch!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Build color list for Firestore (serialisable Map list)
      final colorsData = dominantColors
          .take(5)
          .map((c) => {'r': c[0], 'g': c[1], 'b': c[2]})
          .toList();

      // 3. Save metadata to generated_designs (what library reads)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('generated_designs')
          .add({
        'imageUrl': downloadUrl, // storage URL – no size limit
        'timestamp': FieldValue.serverTimestamp(),
        'style': _selectedStyle,
        'gender': _selectedGender,
        'garment': _selectedGarment,
        'designConcept': _generatedDesignConcept ?? '',
        'colors': colorsData,
      });

      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Saved!',
          text: 'Fashion sketch added to your library.',
        );
      }
    } catch (e) {
      if (mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Save Failed',
          text: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSketch = false);
    }
  }

  void _updateAutoPrompt() {
    String colorInfo = "";
    if (dominantColors.isNotEmpty) {
      final hexList =
          dominantColors.take(5).map((c) => ColorAnalysisService.rgbToHex(c));
      colorInfo =
          "MANDATORY COLOR PALETTE: ${hexList.join(', ')}. You MUST use these exact hex codes in the design description and distribution.";
    }

    String autoText =
        "As a professional fashion designer, generate a highly detailed and editorial design concept for a $_selectedStyle $_selectedGarment designed for $_selectedGender, suitable for a $_selectedOccasion occasion. $colorInfo Focus heavily on how these specific colors are applied to different parts of the garment.";

    // Always update the prompt to reflect current selections
    setState(() {
      _promptController.text = autoText;
    });
  }

  Future<void> _saveToLibrary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _generatedDesignConcept == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('generated_designs')
          .add({
        'userId': user.uid, // Explicitly adding userId for rule consistency
        'designConcept': _generatedDesignConcept,
        'colors': dominantColors,
        'style': _selectedStyle,
        'gender': _selectedGender,
        'occasion': _selectedOccasion,
        'garmentType': _selectedGarment,
        'userPrompt': _promptController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Design saved to your library!"),
            backgroundColor: Color(0xFF9333EA),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Row(
              children: [
                Text(
                  "Fabric Scanner",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
            Text(
              "AI-powered textile analysis",
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 30),

            // MAIN SCAN CARD
            GestureDetector(
              onTap: _showImageSourceDialog,
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
                      color: Colors.purple.withValues(alpha: 0.1),
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
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
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
                                    color: Colors.purple.withValues(alpha: 0.3),
                                    blurRadius: 30,
                                  )
                                ],
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
                              "Tap to\nScan Fabric",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 0.9,
                              ),
                            ),
                            const Spacer(),
                            if (fabricImageBytes != null && !analysisCompleted)
                              GestureDetector(
                                onTap:
                                    _isAnalyzing ? null : analyzeFabricLocally,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9333EA),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF9333EA)
                                            .withOpacity(0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                                  ),
                                  child: _isAnalyzing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black))
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.analytics_rounded,
                                                color: Colors.black, size: 20),
                                            const SizedBox(width: 10),
                                            Text(
                                              "Analyze Now",
                                              style: GoogleFonts.outfit(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ).animate().fadeIn().scale(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(begin: const Offset(0.95, 0.95))
                .shimmer(
                    delay: 2.seconds,
                    duration: 1.5.seconds,
                    color: Colors.white.withValues(alpha: 0.05)),

            const SizedBox(height: 30),

            // SECTION: AI STYLING
            _buildSectionHeader("AI Styling Options")
                .animate()
                .fadeIn(delay: 200.ms)
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  _buildActionCard(
                    "New Scan",
                    "Analyze fabric",
                    Icons.add_a_photo_rounded,
                    onTap: _showImageSourceDialog,
                  ),
                  const SizedBox(width: 16),
                  _buildActionCard(
                    "History",
                    "View saved",
                    Icons.history_rounded,
                    onTap: widget.onHistoryTap,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 30),

            // ANALYSIS RESULTS (SMOOTH RING ANIMATION)
            if (_isAnalyzing ||
                (analysisCompleted && dominantColors.isNotEmpty)) ...[
              const SizedBox(height: 30),
              _buildModernAnalysisProgress()
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 30),
            ],

            if (analysisCompleted && dominantColors.isNotEmpty) ...[
              const SizedBox(height: 40),

              // DESIGN ASSISTANT
              _buildSectionHeader("AI Design Assistant")
                  .animate()
                  .fadeIn()
                  .slideX(begin: -0.1, end: 0),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(32),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Design Style",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _designStyles.map((style) {
                          bool isSelected = _selectedStyle == style;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(style),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedStyle = style);
                                  _updateAutoPrompt();
                                }
                              },
                              labelStyle: GoogleFonts.poppins(
                                color:
                                    Colors.black, // Always black as requested
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              selectedColor: const Color(0xFF9333EA),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Garment Type",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _garmentOptions.map((garment) {
                          bool isSelected = _selectedGarment == garment;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(garment),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedGarment = garment);
                                  _updateAutoPrompt();
                                }
                              },
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              selectedColor: const Color(0xFF9333EA),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Target Gender",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _genderOptions.map((gender) {
                          bool isSelected = _selectedGender == gender;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(gender),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedGender = gender);
                                  _updateAutoPrompt();
                                }
                              },
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              selectedColor: const Color(0xFF9333EA),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Best for Occasion",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _occasionOptions.map((occ) {
                          bool isSelected = _selectedOccasion == occ;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(occ),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedOccasion = occ);
                                  _updateAutoPrompt();
                                }
                              },
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              selectedColor: const Color(0xFF9333EA),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Designer Instructions (Optional)",
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      maxLines: 8, // Increased height
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "e.g. Minimalist silhouette for summer...",
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.white24, fontSize: 13),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF9333EA), width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isGeneratingDesign ? null : _handleGenerateDesign,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: _isGeneratingDesign
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Generate AI Design Concept",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),

              // NEW: DISPLAY RESULTS INLINE
              if (_hasResult) ...[
                const SizedBox(height: 50),
                _buildSectionHeader("AI Design Creation")
                    .animate()
                    .fadeIn()
                    .slideX(begin: -0.1, end: 0),
                const SizedBox(height: 20),
                Container(
                  key: _designResultKey,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Designer Concept result section
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9333EA)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _selectedStyle.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF9333EA),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const Icon(Icons.auto_awesome_rounded,
                              color: Color(0xFF9333EA), size: 20),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Designer's Concept",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _generatedDesignConcept != null
                            ? _getPureDesignText(_generatedDesignConcept!)
                            : "No description available",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Added: Used Colors for reference
                      Text(
                        "Captured Colors Used",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: dominantColors.take(5).map((rgb) {
                          final hex = ColorAnalysisService.rgbToHex(rgb);
                          final color = ColorAnalysisService.mapToColor(rgb);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white24, width: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hex,
                                  style: GoogleFonts.sourceCodePro(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 30),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveToLibrary,
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text("Save Concept"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.05),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() {
                                _hasResult = false;
                                _generatedDesignConcept = null;
                                _generatedSketch = null;
                              }),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text("New Ideas"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9333EA)
                                    .withValues(alpha: 0.1),
                                foregroundColor: const Color(0xFF9333EA),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── AI SKETCH SECTION ──
                      SizedBox(key: _sketchSectionKey, height: 0),
                      const SizedBox(height: 8),
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "AI Fashion Sketch",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                "Powered by Stability AI",
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          _buildCreditsBadge(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Image area
                      if (_generatedSketch != null) ...[
                        GestureDetector(
                          onTap: () => _showFullScreenImage(_generatedSketch!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              children: [
                                Image.memory(
                                  _generatedSketch!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                // Subtle bottom gradient
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.6),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Tap hint badge
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.fullscreen_rounded,
                                            color: Colors.white70, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Tap to expand",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(begin: const Offset(0.97, 0.97)),
                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isGeneratingSketch
                                    ? null
                                    : _generateSketch,
                                icon: _isGeneratingSketch
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded,
                                        size: 18),
                                label: Text(
                                  _isGeneratingSketch
                                      ? "Generating..."
                                      : "Regenerate",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isSavingSketch
                                    ? null
                                    : _saveSketchToLibrary,
                                icon: const Icon(Icons.bookmark_add_rounded,
                                    size: 18),
                                label: Text(
                                  "Save to Library",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9333EA),
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Premium placeholder
                        Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1A1A1A),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9333EA)
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF9333EA),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Your Sketch Awaits",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap below to generate a\nprofessional fashion illustration",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isGeneratingSketch ? null : _generateSketch,
                            icon: _isGeneratingSketch
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome_rounded,
                                    size: 20),
                            label: Text(
                              _isGeneratingSketch
                                  ? "Generating Sketch..."
                                  : "Create Fashion Sketch",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9333EA),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
              ],
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAnalysisProgress() {
    double score = _classificationResult?.score ?? 0.0;
    // Score < 0.5 is fabric
    double fabricConfidence = (1.0 - score).clamp(0.0, 1.0);
    double confidencePercent = (_classificationResult?.confidence ?? 0.0) * 100;

    return Container(
      key: _resultsKey,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAnalyzing ? "Analyzing material..." : "Material Identified",
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              if (analysisCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _classificationResult?.label.toUpperCase() ?? "",
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF9333EA),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                children: [
                  // Outer subtle ring
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 16,
                      color: Colors.white.withOpacity(0.03),
                    ),
                  ),
                  // The main progress ring
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _isAnalyzing ? 0.7 : fabricConfidence,
                      ),
                      duration: Duration(seconds: _isAnalyzing ? 4 : 2),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 16,
                          strokeCap: StrokeCap.round,
                          color: const Color(0xFF9333EA),
                        );
                      },
                    ),
                  ),
                  // Shimmering effect overlay
                  if (_isAnalyzing)
                    const Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 16,
                        strokeCap: StrokeCap.round,
                        color: Colors.white24,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1.seconds),
                  // Center content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isAnalyzing
                              ? "..."
                              : "${confidencePercent.toStringAsFixed(1)}%",
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1),
                        ),
                        Text(
                          _isAnalyzing ? "Processing" : "Confidence",
                          style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (analysisCompleted) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Primary Hue",
                    dominantColors.isNotEmpty
                        ? ColorAnalysisService.rgbToHex(dominantColors[0])
                        : "#---",
                    dominantColors.isNotEmpty
                        ? ColorAnalysisService.mapToColor(dominantColors[0])
                        : Colors.white10,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    "Suggested Use",
                    suggestedUse ?? "Universal",
                    const Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Re-adding the color palette here for accessibility
            Text(
              "Detected Palette",
              style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dominantColors.take(5).map((rgb) {
                final color = ColorAnalysisService.mapToColor(rgb);
                final hex = ColorAnalysisService.rgbToHex(rgb);
                return Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hex,
                      style: GoogleFonts.sourceCodePro(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label,
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF9333EA), size: 28),
              const Spacer(),
              Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(subtitle,
                  style:
                      GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
