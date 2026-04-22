import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login.dart';
import 'edit_profile_page.dart';
import '../controllers/user_controller.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/custom_modern_alert.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfilePage({super.key, this.onBack});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  final UserController _userController = UserController();
  UserModel? _userModel;
  Uint8List? _localImageBytes;
  bool _isUploading = false;
  int _sketchCount = 0;
  int _scanCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final userModel = await _userController.fetchUserData();
    if (mounted) {
      setState(() {
        _userModel = userModel;
      });
    }
    // Also fetch real stats from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final sketches = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sketches')
            .count()
            .get();
        final scans = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('scanned_fabrics')
            .count()
            .get();
        if (mounted) {
          setState(() {
            _sketchCount = sketches.count ?? 0;
            _scanCount = scans.count ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Stats fetch error: $e');
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Update Profile Photo",
              style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
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
                      _pickAndUploadImage(ImageSource.camera);
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
                      _pickAndUploadImage(ImageSource.gallery);
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF5200), size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontFamily: 'Poppins', 
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && _userController.currentUser != null) {
      // 1. Crop the Image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF1A1A1A),
            toolbarWidgetColor: const Color(0xFFFF5200),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            activeControlsWidgetColor: const Color(0xFFFF5200),
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile == null) return;

      final bytes = await File(croppedFile.path).readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _isUploading = true;
      });

      try {
        final uid = _userController.currentUser!.uid;
        // Use a unique name for each upload or overwrite the same file
        String filePath = 'user_profiles/${uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Use putFile with metadata for better reliability
        Reference ref = FirebaseStorage.instance.ref().child(filePath);
        UploadTask uploadTask = ref.putFile(
          File(croppedFile.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 2. Update Firestore
        await _userController.updateUserData(uid, {'photoUrl': downloadUrl});
        
        // 3. Update Firebase Auth Profile
        await _userController.currentUser!.updatePhotoURL(downloadUrl);

        if (mounted) {
          setState(() {
            _localImageBytes = null;
          });
          await _fetchUserData();
          
          CustomModernAlert.show(
            context: context,
            type: CustomAlertType.success,
            title: 'Success',
            message: 'Profile image updated successfully.',
          );
        }
      } catch (e) {
        debugPrint("Error uploading image: $e");
        if (mounted) {
          setState(() => _localImageBytes = null);
          CustomModernAlert.show(
            context: context,
            type: CustomAlertType.error,
            title: 'Upload Error',
            message: 'Failed to upload profile photo.',
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _logout() async {
    CustomModernAlert.show(
      context: context,
      type: CustomAlertType.success,
      title: 'Logged Out',
      message: 'You have been successfully signed out.',
      btnText: 'LOG IN',
      onBtnTap: () async {
        await _userController.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Robust display name: Firestore > Firebase Auth displayName > email prefix > never 'Designer'
    final String displayName = _userModel?.name?.isNotEmpty == true
        ? _userModel!.name!
        : (_userController.currentUser?.displayName?.isNotEmpty == true
            ? _userController.currentUser!.displayName!
            : (_userController.currentUser?.email?.split('@')[0] ?? 'User'));

    final photoUrl =
        _userModel?.photoUrl ?? _userController.currentUser?.photoURL;
    ImageProvider? imageProvider;
    if (_localImageBytes != null) {
      imageProvider = MemoryImage(_localImageBytes!);
    } else if (photoUrl != null) {
      imageProvider = NetworkImage(photoUrl);
    } else {
      imageProvider = null;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                leadingWidth: 70,
                automaticallyImplyLeading: false,
                leading: widget.onBack != null
                    ? Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                color: Theme.of(context).colorScheme.onSurface, size: 16),
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
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideX(begin: -0.2, end: 0),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                          Theme.of(context).colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hi, ${(_userModel?.name ?? _userController.currentUser?.displayName ?? 'Expert').split(' ')[0]}!",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 32,
                                    letterSpacing: -1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _buildMemberSince(),
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
                                      color: const Color(0xFFFF5200), width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                  backgroundImage: imageProvider,
                                  child: _isUploading
                                      ? const CircularProgressIndicator(
                                          color: Color(0xFFFF5200),
                                          strokeWidth: 2)
                                      : (imageProvider == null
                                          ? Icon(Icons.person,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 40)
                                          : null),
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
                      Text(
                        "Style Statistics",
                        style: TextStyle(fontFamily: 'Poppins', 
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildStatTile(
                        "Email",
                        _userModel?.email ??
                            _userController.currentUser?.email ??
                            "—",
                        Icons.email_outlined,
                      ),
                      _buildStatTile(
                        "Member Since",
                        _buildMemberSince(),
                        Icons.calendar_today_outlined,
                      ),
                      _buildStatTile(
                        "Account ID",
                        _userController.currentUser?.uid != null
                            ? "#${_userController.currentUser!.uid.substring(0, 8).toUpperCase()}"
                            : "—",
                        Icons.fingerprint_rounded,
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 40),
                      Text(
                        "Your Journey",
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLiveStatCard(
                              icon: Icons.auto_awesome_rounded,
                              count: _sketchCount,
                              label: "AI Sketches",
                              sublabel: "Generated",
                              highlighted: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildLiveStatCard(
                              icon: Icons.document_scanner_rounded,
                              count: _scanCount,
                              label: "Fabric Scans",
                              sublabel: "Analyzed",
                              highlighted: false,
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 40),
                      Text(
                        "Preferences",
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            _buildThemeToggle(context),
                            Divider(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                indent: 56),
                            _buildActionItem(
                                Icons.edit_outlined, "Edit Profile", onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (c) => EditProfilePage(
                                      userData: _userModel?.toMap(),
                                      onUpdateComplete: _fetchUserData)));
                            }),
                            Divider(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                indent: 56),
                            _buildActionItem(Icons.logout_rounded, "Logout",
                                isDestructive: true, onTap: _logout),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (ModalRoute.of(context)?.isCurrent == true &&
              widget.onBack != null)
            Positioned(
              bottom: 25,
              left: 25,
              right: 25,
              child: CustomBottomNavBar(
                currentIndex: 3,
                onTabTapped: (index) {
                  if (index == 3) return;
                  Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }

  String _buildMemberSince() {
    final createdAt = _userModel?.createdAt;
    if (createdAt != null) {
      final dt = createdAt;
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14),
                ),
                Text(
                  subtitle,
                  style:
                      TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 20),
        ],
      ),
    );
  }

  Widget _buildLiveStatCard({
    required IconData icon,
    required int count,
    required String label,
    required String sublabel,
    required bool highlighted,
  }) {
    final bgColor =
        highlighted ? const Color(0xFFFF5200) : Theme.of(context).colorScheme.surfaceContainerLowest;
    final textColor = highlighted ? Colors.black : Theme.of(context).colorScheme.onSurface;
    final subColor = highlighted ? Colors.black54 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
    final iconBg = highlighted
        ? Colors.black.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    final iconColor = highlighted ? Colors.black87 : const Color(0xFFFF5200);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: highlighted
            ? null
            : Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            count.toString(),
            style: TextStyle(fontFamily: 'Poppins', 
              color: textColor,
              fontSize: 40,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
              color: textColor,
              fontSize: 14,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
              color: subColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title,
      {VoidCallback? onTap, bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon,
          color: isDestructive ? Colors.orangeAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Poppins', 
        color: isDestructive ? Colors.orangeAccent : Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: isDestructive
          ? null
          : Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return ListTile(
      leading: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        "Dark Theme",
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Switch(
        value: isDark,
        onChanged: (v) => themeProvider.toggleTheme(),
        activeColor: const Color(0xFFFF5200),
      ),
    );
  }
}
