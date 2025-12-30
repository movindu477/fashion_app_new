import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  File? fabricImage;
  bool _isUploading = false;
  List<List<int>> dominantColors = [];
  bool analysisCompleted = false;

  Future<void> captureFabricImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        fabricImage = File(image.path);
      });
    }
  }

  Future<void> uploadFabricImage() async {
    if (fabricImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image to upload")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      analysisCompleted = false;
      dominantColors = [];
    });

    try {
      print('Starting upload to: http://192.168.8.100:3000/upload-fabric');
      print('Image path: ${fabricImage!.path}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.8.100:3000/upload-fabric'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'fabric',
          fabricImage!.path,
        ),
      );

      print('Sending request...');
      var response = await request.send();
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('Response body: $responseBody');

        try {
          final decoded = jsonDecode(responseBody);

          // Extract ML analysis results
          if (decoded['analysis'] != null &&
              decoded['analysis']['dominant_colors'] != null) {
            final colors = decoded['analysis']['dominant_colors'];

            setState(() {
              dominantColors = List<List<int>>.from(
                colors.map((c) => List<int>.from(c)),
              );
              analysisCompleted = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Fabric analyzed successfully!"),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Image uploaded but analysis unavailable"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          print('Error parsing response: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image uploaded successfully"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        print(
            'Upload failed. Status: ${response.statusCode}, Body: $errorBody');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: Status ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error during upload: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void analyzeFabricImage() {
    if (fabricImage == null) {
      return;
    }

    uploadFabricImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Texora',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {
              // TODO: Navigate to Profile Page
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              // TODO: Firebase Logout
            },
          ),
        ],
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- WELCOME SECTION --------
            const Text(
              "Hello Designer 👋",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Turn fabric into intelligent fashion sketches",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            // -------- UPLOAD FABRIC (PRIMARY ACTION) --------
            GestureDetector(
              onTap: captureFabricImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black,
                      Colors.grey,
                    ],
                  ),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Upload Fabric Image",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Capture or upload fabric material",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -------- IMAGE PREVIEW --------
            if (fabricImage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    fabricImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: captureFabricImage,
                      child: const Text("Re-capture"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : analyzeFabricImage,
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text("Analyze Fabric"),
                    ),
                  ),
                ],
              ),

              // -------- ML ANALYSIS RESULTS --------
              if (analysisCompleted && dominantColors.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "Detected Fabric Colors",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: dominantColors.map((color) {
                    return Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          color[0],
                          color[1],
                          color[2],
                          1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // -------- DESIGN INPUTS --------
            const Text(
              "Design Inputs",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _InputChip(label: "Fabric Type"),
                _InputChip(label: "Dress Type"),
                _InputChip(label: "Style Keywords"),
                _InputChip(label: "Body Type"),
                _InputChip(label: "Occasion"),
              ],
            ),

            const SizedBox(height: 28),

            // -------- AI TOOLS --------
            const Text(
              "AI Tools",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: const [
                _AiActionCard(
                  icon: Icons.analytics_outlined,
                  title: "Analyze Fabric",
                  subtitle: "Detect color & texture",
                ),
                SizedBox(width: 12),
                _AiActionCard(
                  icon: Icons.auto_awesome_outlined,
                  title: "Generate Sketch",
                  subtitle: "AI fashion design",
                ),
              ],
            ),

            const SizedBox(height: 28),

            // -------- RECENT SKETCHES --------
            const Text(
              "Recent Sketches",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Sketch\nPreview",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ================= BOTTOM NAVIGATION =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            label: "Generate",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: "Saved",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// ================= INPUT CHIP =================
class _InputChip extends StatelessWidget {
  final String label;

  const _InputChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ================= AI ACTION CARD =================
class _AiActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AiActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // TODO: Navigate to AI screen
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
