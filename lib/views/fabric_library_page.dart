import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/custom_modern_alert.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FabricLibraryPage extends StatefulWidget {
  const FabricLibraryPage({super.key});

  @override
  State<FabricLibraryPage> createState() => _FabricLibraryPageState();
}

class _FabricLibraryPageState extends State<FabricLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login to view your library"));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Text(
                "My Collection",
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(color: const Color(0xFF0F0F0F)),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF5200),
              labelColor: const Color(0xFFFF5200),
              unselectedLabelColor: Colors.white38,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, ),
              tabs: const [
                Tab(text: "Scanned Fabrics"),
                Tab(text: "AI Designs"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDataList(context, 'scanned_fabrics'),
            _buildDataList(context, 'generated_designs'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataList(BuildContext context, String collection) {
    final user = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5200)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text(
                  "No items found here",
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                      color: Colors.white,
                      fontSize: 18,
                      ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildItemCard(context, data, doc.id, collection);
          },
        );
      },
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> data,
      String docId, String collection) {
    final isDesign = collection == 'generated_designs';
    final imageUrl = data['imageUrl'] as String?; // Firebase Storage URL
    final imageBase64 = data['imageBase64'] as String?; // scanned fabric base64
    final sketchBase64 = data['sketchBase64'] as String?; // AI design base64
    final fabricBase64 = data['fabricBase64'] as String?;
    final imagePath = data['imagePath'] as String?;
    
    final title = isDesign
        ? (data['style'] ?? "Custom Design")
        : (data['fabricType'] ?? data['suggestedUse'] ?? "Fabric Scan");
    final colors = _parseColors(data['dominantColors'] ?? data['colors']);

    return GestureDetector(
      onTap: () => _showDetails(context, data, docId, collection),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Optimized Image Loading (prioritize cloud URL)
            imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF5200),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                    errorBuilder: (ctx, err, stack) => Container(
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image_rounded,
                          color: Colors.white12, size: 30),
                    ),
                  )
                : (sketchBase64 != null
                    ? Image.memory(base64Decode(sketchBase64), fit: BoxFit.cover)
                    : (imageBase64 != null
                        ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
                        : (fabricBase64 != null
                            ? Image.memory(base64Decode(fabricBase64), fit: BoxFit.cover)
                            : (imagePath != null && File(imagePath).existsSync()
                                ? Image.file(File(imagePath), fit: BoxFit.cover)
                                : Container(
                                    color: Colors.black26,
                                    child: const Icon(Icons.style_rounded,
                                        color: Colors.white12)))))),

            // Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                        color: Colors.white,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: colors
                        .take(3)
                        .map((c) => Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                  color: c, shape: BoxShape.circle),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

            // Delete
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () =>
                    _confirmDelete(context, docId, imagePath, collection),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white70, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
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

  void _showDetails(BuildContext context, Map<String, dynamic> data,
      String docId, String collection) {
    final isDesign = collection == 'generated_designs';
    final colors = _parseColors(data['dominantColors'] ?? data['colors']);
    final imageUrl = data['imageUrl'] as String?;
    final sketchBase64 = data['sketchBase64'] as String?;
    final fabricBase64 = data['fabricBase64'] as String?;
    final imagePath = data['imagePath'] as String?;
    final designConcept = data['designConcept'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)))),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) => progress ==
                                  null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFFF5200))))
                      : (sketchBase64 != null
                          ? Image.memory(base64Decode(sketchBase64),
                              fit: BoxFit.cover)
                          : (fabricBase64 != null
                              ? Image.memory(base64Decode(fabricBase64),
                                  fit: BoxFit.cover)
                              : (imagePath != null && File(imagePath).existsSync()
                                  ? Image.file(File(imagePath), fit: BoxFit.cover)
                                  : Container(color: Colors.black26)))),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isDesign ? "AI Design Creation" : "Fabric Report",
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                    color: const Color(0xFFFF5200),
                    fontSize: 14,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                isDesign
                    ? (data['style'] ?? "Custom Design")
                    : (data['suggestedUse'] ?? "Unknown Fabric"),
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.1),
              ),
              const SizedBox(height: 24),
              if (isDesign && designConcept != null) ...[
                Text("Design Concept",
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                        color: Colors.white,
                        fontSize: 18,
                        )),
                const SizedBox(height: 8),
                Text(designConcept,
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                        color: Colors.white70, fontSize: 14, height: 1.6)),
                const SizedBox(height: 24),
              ],
              Text("Color Palette",
                  style: TextStyle(fontFamily: 'Poppins', 
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors
                    .map((color) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Text(
                                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                                      color: Colors.white,
                                      fontSize: 12)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () =>
                    _confirmDelete(context, docId, imagePath, collection),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text("Delete from Library"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String? imagePath,
      String collection) {
    CustomModernAlert.show(
      context: context,
      type: CustomAlertType.error,
      title: 'Delete Item?',
      message: 'This will permanently remove this record.',
      btnText: 'Delete',
      onBtnTap: () async {
        Navigator.pop(context);
        final user = FirebaseAuth.instance.currentUser!;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collection)
            .doc(docId)
            .delete();
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) await file.delete();
        }
      },
    );
  }
}
