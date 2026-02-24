import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickalert/quickalert.dart';
import '../services/color_analysis_service.dart';
import '../services/gemini_service.dart';

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
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  Uint8List? fabricImageBytes;
  String? fabricImagePath;
  bool _isAnalyzing = false;
  List<Map<String, int>> dominantColors = [];
  bool analysisCompleted = false;
  String? suggestedUse;

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
    _videoController =
        VideoPlayerController.asset('assets/videos/fabric_bg.mp4')
          ..initialize().then((_) {
            setState(() {});
            _videoController.setLooping(true);
            _videoController.play();
          });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> captureFabricImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        fabricImageBytes = bytes;
        fabricImagePath = image.path;
        analysisCompleted = false;
        dominantColors = [];
      });
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
      if (mounted) setState(() => _isAnalyzing = false);
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

        // Smooth scroll to the result
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_designResultKey.currentContext != null) {
            Scrollable.ensureVisible(
              _designResultKey.currentContext!,
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

  void _updateAutoPrompt() {
    String colorInfo = "";
    if (dominantColors.isNotEmpty) {
      final hexList =
          dominantColors.take(5).map((c) => ColorAnalysisService.rgbToHex(c));
      colorInfo =
          "strictly using the following color codes: ${hexList.join(', ')}";
    }

    String autoText =
        "As a professional fashion designer, generate a highly detailed design concept for a $_selectedStyle $_selectedGarment designed for $_selectedGender, suitable for a $_selectedOccasion occasion, $colorInfo. Focus on how these exact colors are distributed throughout the garment.";

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
            backgroundColor: Color(0xFFCCFF00),
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
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFFCCFF00), size: 24),
              ],
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
            Text(
              "AI-powered textile analysis",
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
            ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 30),

            // MAIN SCAN CARD
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
                              ElevatedButton(
                                onPressed:
                                    _isAnalyzing ? null : analyzeFabricLocally,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                child: _isAnalyzing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black))
                                    : const Text("Analyze Now",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                              ),
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
                    onTap: captureFabricImage,
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

            // ANALYSIS RESULTS
            if (analysisCompleted && dominantColors.isNotEmpty) ...[
              const SizedBox(height: 30),
              _buildSectionHeader("Analysis Result")
                  .animate()
                  .fadeIn()
                  .slideX(begin: -0.1, end: 0),
              const SizedBox(height: 16),
              Container(
                key: _resultsKey,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: const Color(0xFFCCFF00).withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCCFF00).withValues(alpha: 0.05),
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
                            borderRadius: BorderRadius.circular(16),
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
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                "AI Textile Intelligence",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFCCFF00)
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly, // Equal spacing
                      children: dominantColors.take(5).map((rgb) {
                        final hex = ColorAnalysisService.rgbToHex(rgb);
                        final color = ColorAnalysisService.mapToColor(rgb);
                        return GestureDetector(
                          onTap: () {
                            // Copy to clipboard or just show snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Color $hex selected"),
                                duration: const Duration(milliseconds: 500),
                                backgroundColor: color,
                              ),
                            );
                            _updateAutoPrompt(); // Refresh prompt
                          },
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                hex.substring(1),
                                style: TextStyle(
                                  color: color.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ).animate().scale(delay: 400.ms),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.98, 0.98)),

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
                              selectedColor: const Color(0xFFCCFF00),
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
                              selectedColor: const Color(0xFFCCFF00),
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
                              selectedColor: const Color(0xFFCCFF00),
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
                              selectedColor: const Color(0xFFCCFF00),
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
                              color: Color(0xFFCCFF00), width: 1),
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
                          backgroundColor: const Color(0xFFCCFF00),
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
                        color: const Color(0xFFCCFF00).withValues(alpha: 0.1)),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFF00)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedStyle.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFCCFF00),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const Icon(Icons.auto_awesome_rounded,
                              color: Color(0xFFCCFF00), size: 20),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Triggering navigation via HomePage's _onTabTapped
                            // Since we don't have direct access here, we use the callback
                            // The callback already updated the shared state.
                            // We just need to tell the parent to switch tabs.

                            // For simplicity, we can use the snacker as a confirmation then switch
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Switching to AI Sketch...",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Color(0xFFCCFF00),
                                duration: Duration(milliseconds: 800),
                              ),
                            );

                            // Find the HomePage state to switch tabs
                            dynamic parent =
                                context.findAncestorStateOfType<State>();
                            while (parent != null &&
                                parent.runtimeType.toString() !=
                                    "_HomePageState") {
                              parent = parent.context
                                  .findAncestorStateOfType<State>();
                            }

                            if (parent != null) {
                              parent._onTabTapped(3);
                            }
                          },
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text(
                            "Generate Professional Sketch",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCCFF00),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() {
                                _hasResult = false;
                                _generatedDesignConcept = null;
                              }),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text("New Ideas"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCCFF00)
                                    .withValues(alpha: 0.1),
                                foregroundColor: const Color(0xFFCCFF00),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
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
              Icon(icon, color: const Color(0xFFCCFF00), size: 28),
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
