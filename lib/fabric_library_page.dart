import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

class FabricLibraryPage extends StatelessWidget {
  const FabricLibraryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login to view your library"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF9F9F9),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                "Fabric Library",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(color: const Color(0xFFF9F9F9)),
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(Icons.style_outlined,
                              size: 48, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Your Collection is Empty",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Scan fabrics to build your digital wardrobe",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65, // Taller cards to prevent overflow
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildFabricCard(context, data);
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

  Widget _buildFabricCard(BuildContext context, Map<String, dynamic> data) {
    // Handle Image Source (Base64 vs URL)
    final imageUrl = data['imageUrl'] as String?;
    final isBase64 = data['isBase64'] == true;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final suggestedUse = data['suggestedUse'] as String? ?? "Unknown";
    final colors = _parseColors(data['colors']);

    return GestureDetector(
      onTap: () => _showFabricDetails(context, data),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // Dark background for the whole card
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 5, // Increased image ratio
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20), bottom: Radius.circular(0)),
                    child: _buildImageWidget(imageUrl, isBase64),
                  ),
                  // Date Badge (Modernized)
                  if (timestamp != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 0.5),
                        ),
                        child: Text(
                          "${timestamp.day}/${timestamp.month}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Section (Black description part)
            Expanded(
              flex: 2, // Compact description
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF121212), // Darker black for footer
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(0), bottom: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestedUse,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // White text
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Analyzed Texture",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mini Color Palette Preview
                    Row(
                      children: [
                        ...colors.take(3).map((c) => Align(
                              widthFactor: 0.6,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF121212), width: 2),
                                ),
                              ),
                            )),
                        if (colors.length > 3)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            child: Text(
                              "+${colors.length - 3}",
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to handle both URL and Base64 images
  Widget _buildImageWidget(String? source, bool isBase64) {
    if (source == null) {
      return Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image, color: Colors.grey));
    }

    if (isBase64) {
      try {
        Uint8List bytes = base64Decode(source);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (e) {
        return Container(color: Colors.grey[200]);
      }
    } else {
      return Image.network(
        source,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) =>
            p == null ? child : Container(color: Colors.grey[100]),
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[100]),
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

  void _showFabricDetails(BuildContext context, Map<String, dynamic> data) {
    final colors = _parseColors(data['colors']);
    final imageUrl = data['imageUrl'] as String?;
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
            color: Colors.white,
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
                          child: _buildImageWidget(imageUrl, isBase64),
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
                                  color: Color(0xFFFF5200),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['suggestedUse'] ?? "Unknown Material",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.share_outlined, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Color Palette Section
                    const Text(
                      "Extracted Palette",
                      style: TextStyle(
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "RGB: ${color.red}, ${color.green}, ${color.blue}",
                                    style: TextStyle(
                                      color: Colors.grey[500],
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
}
