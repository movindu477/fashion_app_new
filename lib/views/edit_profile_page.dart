import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback onUpdateComplete;

  const EditProfilePage({
    super.key,
    required this.userData,
    required this.onUpdateComplete,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController; // Example extra field
  late TextEditingController _bioController; // Example extra field
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.userData?['name'] ?? '');
    _phoneController =
        TextEditingController(text: widget.userData?['phone'] ?? '');
    _bioController = TextEditingController(text: widget.userData?['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'bio': _bioController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update Auth Display Name
        await user.updateDisplayName(_nameController.text.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Updated Successfully!")),
          );
          widget.onUpdateComplete(); // Callback to refresh parent
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error updating profile: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Semi-transparent barrier for the "center panel" effect request,
    // or just a full page because "slide from left" implies a navigation transition.
    // The user asked for "panel should be smoothly come from left side to the center".
    // I will implement this as a full page with the transition handled by the Navigator push,
    // but Style it like a centered panel if possible, or just a clean page.
    // Given the phrasing "come from left side...", a page transition is best.

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
            color: Colors.white,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personal Information",
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                  "Full Name", _nameController, Icons.person_outline_rounded),
              const SizedBox(height: 20),
              _buildTextField("Phone Number", _phoneController,
                  Icons.phone_android_rounded),
              const SizedBox(height: 20),
              _buildTextField("Bio", _bioController, Icons.textsms_outlined,
                  maxLines: 4),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5200),
                    foregroundColor: Colors.black,
                    elevation: 8,
                    shadowColor: const Color(0xFFFF5200).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5))
                      : Text(
                          "Save Changes",
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400,
                              fontSize: 18,
                              letterSpacing: -0.2),
                        ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 40),
            ],
          ).animate().fadeIn(duration: 600.ms),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, 
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400, color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                color: const Color(0xFFFF5200).withValues(alpha: 0.7),
                size: 22),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: Color(0xFFFF5200), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: (val) => val == null || val.isEmpty ? "Required" : null,
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05, end: 0);
  }
}
