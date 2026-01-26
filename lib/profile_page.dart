import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'login.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  User? _user;
  Map<String, dynamic>? _userData;
  File? _localImageFile;
  bool _isUploading = false;

  @override
  bool get wantKeepAlive => true; // Keeps page alive

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
        // Handle error
      }
    }
  }

  void _navigateToEditProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditProfilePage(
          userData: _userData,
          onUpdateComplete: _fetchUserData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0); // Slide from Left
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ... (Existing _pickAndUploadImage and _logout methods remain the same but must be included or preserved.
  // Since I am replacing a chunk, I must include them or ensure start/end guidelines preserve them.
  // The 'ReplacementContent' must replace the targeted chunk.
  // I will target the imports down to the Menu List to insert the new logic.)

  // WAIT, I need to be careful not to delete methods.
  // I will use `replace_file_content` strategically.

  // STRATEGY:
  // 1. Add 'edit_profile_page.dart' import.
  // 2. Add Mixin and wantKeepAlive.
  // 3. Add _navigateToEditProfile method.
  // 4. Update the "Edit Profile" tile to call _navigateToEditProfile.

  // I will do a massive replacement of the top class definition and build method to be safe,
  // but I need to keep the image upload logic intact.

  // Let's replace the imports and class definition first.

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && _user != null) {
      setState(() {
        _localImageFile = File(pickedFile.path);
        _isUploading = true;
      });

      File file = File(pickedFile.path);
      try {
        // 1. Upload to Firebase Storage
        String filePath = 'user_profiles/${_user!.uid}_profile.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(filePath);
        UploadTask uploadTask = ref.putFile(file);

        // Wait for upload to complete
        TaskSnapshot snapshot = await uploadTask;

        // 2. Get URL
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 3. Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'photoUrl': downloadUrl});

        // 4. Update Auth Profile
        await _user!.updatePhotoURL(downloadUrl);

        // 5. Update Local State (Clear local file to use network url now)
        if (mounted) {
          setState(() {
            _localImageFile = null; // Switch back to network image
          });
          await _fetchUserData();
        }
      } catch (e) {
        print("Error uploading image: $e");
        if (mounted) {
          setState(() {
            _localImageFile = null; // Revert on failure
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload image: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Determine Display Name
    final displayName = _userData?['name'] ??
        _user?.displayName ??
        _user?.email?.split('@')[0] ??
        "Designer";
    final email = _userData?['email'] ?? _user?.email ?? "janeper01@gmail.com";

    // Determine Photo Provider
    // 1. Local Preview
    // 2. Network URL from Firestore/Auth
    // 3. Asset Fallback
    final photoUrl = _userData?['photoUrl'] ?? _user?.photoURL;

    ImageProvider imageProvider;
    if (_localImageFile != null) {
      imageProvider = FileImage(_localImageFile!);
    } else if (photoUrl != null) {
      imageProvider = NetworkImage(photoUrl);
    } else {
      imageProvider = const AssetImage('assets/images/logo.png');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
        children: [
          // 1. Dark Header Section
          Container(
            padding:
                const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF18191E), // Dark nearly black background
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderIconBtn(Icons.arrow_back_ios_new, () {}),
                    const Text(
                      "Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildHeaderIconBtn(Icons.shopping_bag_outlined, () {}),
                  ],
                ),

                const SizedBox(height: 20),

                // Profile Image with Edit Button
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: imageProvider,
                        child: _isUploading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5200), // Orange accent
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF18191E), width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Name & Email
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22, // Size adjusted to look like image
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 30),

                // Quick Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickActionItem(
                        Icons.notifications_none, "Notification"),
                    _buildQuickActionItem(Icons.card_giftcard, "Voucher"),
                    _buildQuickActionItem(Icons.history, "History"),
                  ],
                ),
              ],
            ),
          ),

          // 2. Menu List Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  _buildMenuTile(Icons.person_outline, "Edit Profile",
                      onTap: _navigateToEditProfile),
                  _buildMenuTile(
                      Icons.location_on_outlined, "Address Management"),
                  _buildMenuTile(Icons.headset_mic_outlined, "Help & Support"),
                  _buildMenuTile(Icons.settings_outlined, "Setting"),
                  _buildMenuTile(Icons.logout, "Log out",
                      isDestructive: true, onTap: _logout),

                  const SizedBox(height: 100), // Bottom padding for nav bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label) {
    return Container(
      width: 100, // Fixed width for uniformity
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF25262B), // Slightly lighter dark shade
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title,
      {bool isDestructive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : Colors.black54,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDestructive
                      ? Colors.redAccent
                      : const Color(0xFF1F2024),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isDestructive)
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}
