import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dart:ui';
import 'login.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfilePage({super.key, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  User? _user;
  Map<String, dynamic>? _userData;
  Uint8List? _localImageBytes;
  bool _isUploading = false;

  @override
  bool get wantKeepAlive => true;

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
        debugPrint("Error fetching user data: $e");
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.black87),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.black87),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && _user != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _isUploading = true;
      });

      try {
        String filePath = 'user_profiles/${_user!.uid}_profile.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(filePath);
        UploadTask uploadTask = ref.putData(bytes);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'photoUrl': downloadUrl});

        await _user!.updatePhotoURL(downloadUrl);

        if (mounted) {
          setState(() {
            _localImageBytes = null;
          });
          await _fetchUserData();
        }
      } catch (e) {
        debugPrint("Error uploading image: $e");
        if (mounted) {
          setState(() => _localImageBytes = null);
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

    final String displayName = _userData?['name']?.toString() ??
        _user?.displayName ??
        _user?.email?.split('@')[0] ??
        "Designer";

    final photoUrl = _userData?['photoUrl'] ?? _user?.photoURL;
    ImageProvider imageProvider;
    if (_localImageBytes != null) {
      imageProvider = MemoryImage(_localImageBytes!);
    } else if (photoUrl != null) {
      imageProvider = NetworkImage(photoUrl);
    } else {
      imageProvider = const AssetImage('assets/images/logo.png');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            surfaceTintColor: Colors.transparent,
            leadingWidth: 70,
            leading: widget.onBack != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                        onPressed: widget.onBack,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                  left: widget.onBack != null ? 70 : 20, bottom: 16),
              title: Text(
                "Profile",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A1A1A),
                      Color(0xFF0F0F0F),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP HEADER (Refined)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hi, $displayName!",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _buildMemberSince(),
                              style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFCCFF00), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white12,
                              backgroundImage: imageProvider,
                              child: _isUploading
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFFCCFF00), strokeWidth: 2)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 40),

                  // 2. STYLE STATS
                  Text(
                    "Style Statistics",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildStatTile(
                    "Email",
                    _userData?['email'] ?? _user?.email ?? "—",
                    Icons.email_outlined,
                  ),
                  _buildStatTile(
                    "Member Since",
                    _buildMemberSince(),
                    Icons.calendar_today_outlined,
                  ),
                  _buildStatTile(
                    "Account ID",
                    _user?.uid != null
                        ? "#${_user!.uid.substring(0, 8).toUpperCase()}"
                        : "—",
                    Icons.fingerprint_rounded,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 40),

                  // 3. YOUR JOURNEY
                  Text(
                    "Your Journey",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _buildProgressCard(
                          _userData?['name']?.toString() ?? displayName,
                          "Your Name",
                          100,
                          const Color(0xFFCCFF00),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildProgressColorCard(
                          _user?.email?.split('@')[0] ?? "Designer",
                          "Username",
                          75,
                          const Color(0xFFCCFF00),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 40),

                  // 4. SETTINGS & ACTIONS
                  Text(
                    "Preferences",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _buildActionItem(Icons.edit_outlined, "Edit Profile",
                            onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (c) => EditProfilePage(
                                  userData: _userData,
                                  onUpdateComplete: _fetchUserData)));
                        }),
                        Divider(
                            color: Colors.white.withOpacity(0.05), indent: 56),
                        _buildActionItem(Icons.logout_rounded, "Logout",
                            isDestructive: true, onTap: _logout),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 120), // Padding for nav bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildMemberSince() {
    final createdAt = _userData?['createdAt'];
    if (createdAt != null && createdAt is Timestamp) {
      final dt = createdAt.toDate();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return 'Member since ${months[dt.month - 1]} ${dt.year}';
    }
    return 'Member since —';
  }

  Widget _buildStatTile(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.bookmark_outline_rounded,
              color: Colors.white24, size: 20),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
      String title, String level, int progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.toString(),
                style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              _buildMiniProgressBars(progress, Colors.black26),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Keep it up!",
            style: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
                color: Colors.black, fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressColorCard(
      String title, String level, int progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.toString(),
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              _buildMiniProgressBars(progress, color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Weekly Goal",
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgressBars(int progress, Color color) {
    return Row(
      children: List.generate(5, (index) {
        bool active = (index + 1) * 20 <= progress;
        return Container(
          width: 4,
          height: 12,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildActionItem(IconData icon, String title,
      {VoidCallback? onTap, bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon,
          color: isDestructive ? Colors.orangeAccent : Colors.white70),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isDestructive ? Colors.orangeAccent : Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: isDestructive
          ? null
          : const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }
}
