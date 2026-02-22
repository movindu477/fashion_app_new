import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:quickalert/quickalert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class FabricLibraryPage extends StatelessWidget {
  const FabricLibraryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login to view your library"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                "Fabric Library",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
              background: Container(color: const Color(0xFF0F0F0F)),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('analyses')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(Icons.style_outlined,
                              size: 48, color: Colors.white.withOpacity(0.1)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Your Collection is Empty",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Scan fabrics to build your digital wardrobe",
                          style: GoogleFonts.poppins(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildFabricCard(context, data, doc.id)
                          .animate()
                          .fadeIn(delay: (index * 100).ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0);
                    },
                    childCount: snapshot.data!.docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFabricCard(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final imageUrl = data['imageUrl'] as String?;
    final imagePath = data['imagePath'] as String?;
    final isBase64 = data['isBase64'] == true;
    final suggestedUse = data['suggestedUse'] as String? ?? "Unknown";
    final colors = _parseColors(data['dominantColors'] ?? data['colors']);

    return GestureDetector(
      onTap: () => _showFabricDetails(context, data, docId),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image
              _buildImageWidget(imageUrl, isBase64, imagePath),

              // 2. Dark Gradient Overlay (Bottom half)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Delete Button (Modern)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context, docId, imagePath),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // 4. More Info Button (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 14,
                  ),
                ),
              ),

              // 5. Content Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(28)),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestedUse,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          // Action Pill (Modern Styled)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCCFF00),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Detail",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              // Palette Button
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ...colors.take(1).map((c) => Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: c.withOpacity(0.4),
                                                blurRadius: 4,
                                              )
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to handle URL, Base64, and Local File images
  Widget _buildImageWidget(String? source, bool isBase64, [String? localPath]) {
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }

    if (source == null) {
      return Container(
          color: const Color(0xFF121212),
          child:
              Icon(Icons.broken_image, color: Colors.white.withOpacity(0.05)));
    }

    if (isBase64) {
      try {
        Uint8List bytes = base64Decode(source);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (e) {
        return Container(color: const Color(0xFF121212));
      }
    } else {
      return Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : Container(color: const Color(0xFF121212)),
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF121212)),
      );
    }
  }

  // Robust color parser handling List<List<int>> AND List<Map<String, dynamic>>
  List<Color> _parseColors(dynamic colorsData) {
    List<Color> result = [];
    if (colorsData == null) return result;

    if (colorsData is List) {
      for (var item in colorsData) {
        if (item is List && item.length >= 3) {
          // Old Format: [r, g, b]
          result.add(Color.fromRGBO(item[0], item[1], item[2], 1.0));
        } else if (item is Map) {
          // New Format: {r: 10, g: 20, b: 30}
          // Handle both String keys "r" and implicit dynamic keys
          int r = (item['r'] ?? 0) as int;
          int g = (item['g'] ?? 0) as int;
          int b = (item['b'] ?? 0) as int;
          result.add(Color.fromRGBO(r, g, b, 1.0));
        }
      }
    }
    return result;
  }

  void _showFabricDetails(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final colors = _parseColors(data['dominantColors'] ?? data['colors']);
    final imageUrl = data['imageUrl'] as String?;
    final imagePath = data['imagePath'] as String?;
    final isBase64 = data['isBase64'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Large Header Image
                    Hero(
                      tag: 'fabric_detail', // simple tag
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 250,
                          width: double.infinity,
                          child:
                              _buildImageWidget(imageUrl, isBase64, imagePath),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Fabric Report",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFCCFF00),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['suggestedUse'] ?? "Unknown Material",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close detail view
                            _confirmDelete(context, docId, imagePath);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.delete_forever_rounded,
                                color: Color(0xFFCCFF00), size: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.share_outlined,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Color Palette Section
                    Text(
                      "Extracted Palette",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: colors.map((color) {
                        final hex =
                            '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hex,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "RGB: ${color.red}, ${color.green}, ${color.blue}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String? imagePath) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.warning,
      title: 'Delete Forever?',
      text: 'This will remove the data and the local image file.',
      confirmBtnText: 'Delete',
      confirmBtnColor: const Color(0xFFCCFF00),
      onConfirmBtnTap: () async {
        Navigator.pop(context); // Close dialog
        await _deleteAnalysis(context, docId, imagePath);
      },
      showCancelBtn: true,
    );
  }

  Future<void> _deleteAnalysis(
      BuildContext context, String docId, String? imagePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Delete Firestore Document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('analyses')
          .doc(docId)
          .delete();

      // 2. Delete Local File (Auto-cleanup to save storage)
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          debugPrint("🗑️ Deleting local file: $imagePath");
          await file.delete();
        }
      }

      if (context.mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Deleted',
          text: 'Analysis and image removed successfully!',
          autoCloseDuration: const Duration(seconds: 1),
          showConfirmBtn: false,
        );
      }
    } catch (e) {
      debugPrint("❌ Delete error: $e");
      if (context.mounted) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Error',
          text: 'Failed to delete: $e',
        );
      }
    }
  }
}
