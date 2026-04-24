import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_modern_alert.dart';
import '../services/stability_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AiDesignPage extends StatefulWidget {
  final String? designConcept;
  final List<Map<String, int>>? dominantColors;
  final Uint8List? fabricImage;
  final String? selectedStyle;
  final String? selectedGender;
  final String? selectedGarment;

  const AiDesignPage({
    super.key,
    this.designConcept,
    this.dominantColors,
    this.fabricImage,
    this.selectedStyle,
    this.selectedGender,
    this.selectedGarment,
  });

  @override
  State<AiDesignPage> createState() => _AiDesignPageState();
}

class _AiDesignPageState extends State<AiDesignPage>
    with WidgetsBindingObserver {
  final StabilityService _stabilityService = StabilityService();
  Uint8List? _generatedSketch;
  bool _isGenerating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync credits when the user comes back from the top-up page
      StabilityService().syncBalanceFromApi();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Credits status refreshed",
              style: TextStyle(color: Colors.black)),
          backgroundColor: Color(0xFFFF5200),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _generateSketch() async {
    if (widget.designConcept == null) {
      CustomModernAlert.show(
        context: context,
        type: CustomAlertType.error,
        title: 'No Concept',
        message: 'Please generate a design concept in the Scan page first!',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final sketch = await _stabilityService.generateFashionSketch(
        widget.designConcept!,
        targetGender: widget.selectedGender ?? "Unisex",
        colors: widget.dominantColors,
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
          CustomModernAlert.show(
            context: context,
            type: CustomAlertType.error,
            title: 'Sketch Failed',
            message: e.toString(),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showTopUpDialog() {
    CustomModernAlert.show(
      context: context,
      type: CustomAlertType.error,
      title: 'Top Up Required',
      message: 'You need more credits to generate a professional sketch.',
      btnText: 'Top Up Now',
      onBtnTap: () async {
        Navigator.pop(context);
        final url = Uri.parse('https://stability.ai/generate');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      },
    );
  }

  Future<void> _saveToLibrary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        widget.designConcept == null ||
        _generatedSketch == null) return;

    setState(() => _isSaving = true);

    try {
      // For Firestore, we store the generated image as a base64 string
      // and the fabric image (if small enough/needed) or path.
      // Since fabricImage is Uint8List here, we base64 it too.
      final String sketchBase64 = base64Encode(_generatedSketch!);
      final String? fabricBase64 =
          widget.fabricImage != null ? base64Encode(widget.fabricImage!) : null;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('generated_designs')
          .add({
        'userId': user.uid,
        'designConcept': widget.designConcept,
        'sketchBase64': sketchBase64,
        'fabricBase64': fabricBase64,
        'colors': widget.dominantColors,
        'style': widget.selectedStyle,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        CustomModernAlert.show(
          context: context,
          type: CustomAlertType.success,
          title: 'Saved!',
          message: 'The sketch and fabric reference have been saved to your library.',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomModernAlert.show(
          context: context,
          type: CustomAlertType.error,
          title: 'Save Failed',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Fashion Sketch",
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                          color: Colors.white,
                          fontSize: 28,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCreditsBadge(),
              ],
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
            const SizedBox(height: 30),
            if (widget.designConcept == null)
              _buildPlaceholder()
            else ...[
              _buildConceptCard(),
              const SizedBox(height: 30),
              if (_generatedSketch != null)
                _buildSketchResult()
              else
                _buildGenerateButton(),
            ],
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_motion_rounded,
              size: 64, color: Colors.white10),
          const SizedBox(height: 20),
          Text(
            "Waiting for a concept...",
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                color: Colors.white, fontSize: 18, ),
          ),
          const SizedBox(height: 10),
          Text(
            "Go to the Scan tab to analyze fabric and generate a designer concept first.",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildConceptCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: const Color(0xFFFF5200).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.fabricImage != null)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                        image: MemoryImage(widget.fabricImage!),
                        fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Current Concept",
                        style: TextStyle(fontFamily: 'Poppins', 
                            color: const Color(0xFFFF5200),
                            fontWeight: FontWeight.w400,
                            fontSize: 13)),
                    Text(widget.selectedStyle ?? "Custom Style",
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                            color: Colors.white,
                            fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            widget.designConcept!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateSketch,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5200),
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isGenerating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 12),
                  Text("Generate Visual Sketch",
                      style: TextStyle(fontFamily: 'Poppins', 
                          fontWeight: FontWeight.w400, fontSize: 18)),
                ],
              ),
      ),
    );
  }

  Widget _buildSketchResult() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 500,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            image: DecorationImage(
                image: MemoryImage(_generatedSketch!), fit: BoxFit.cover),
            boxShadow: [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  offset: const Offset(0, 10))
            ],
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveToLibrary,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_rounded),
                label: const Text("Save to Collection"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generateSketch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Regenerate"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5200),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreditsBadge() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int credits = 0;
        bool hasUserCredits = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('credits')) {
            credits = data['credits'] ?? 0;
            hasUserCredits = true;
          }
        }

        // Fallback to global pool only if user has no personal credits field
        if (!hasUserCredits) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app_settings')
                .doc('system')
                .snapshots(),
            builder: (context, sysSnapshot) {
              int sysCredits = 0;
              if (sysSnapshot.hasData && sysSnapshot.data!.exists) {
                sysCredits = sysSnapshot.data!.get('image_credits') ?? 0;
              }
              return _buildCreditContainer(sysCredits);
            },
          );
        }

        return _buildCreditContainer(credits);
      },
    );
  }

  Widget _buildCreditContainer(int credits) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5200).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF5200).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFFF5200), size: 16),
          const SizedBox(width: 6),
          Text(
            "$credits Credits",
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
              color: const Color(0xFFFF5200),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
