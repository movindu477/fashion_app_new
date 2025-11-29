import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:async';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late VideoPlayerController _videoController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _isVideoInitialized = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkFirebaseInitialization();
  }

  Future<void> _checkFirebaseInitialization() async {
    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase not initialized, attempting to initialize...');
        // This should not happen if main.dart is correct, but just in case
      } else {
        print('✅ Firebase is initialized');
      }
    } catch (e) {
      print('❌ Firebase check error: $e');
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/images/reg.mp4');
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.play();
        _videoController.setLooping(true);
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      print('🔄 Starting registration process for: $email');

      // Check internet connection
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw Exception('No internet connection');
        }
      } on SocketException catch (_) {
        _showErrorMessage(
            "No internet connection. Please check your connection.");
        setState(() => _loading = false);
        return;
      } on TimeoutException catch (_) {
        _showErrorMessage(
            "Connection timeout. Please check your internet connection.");
        setState(() => _loading = false);
        return;
      }

      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        _showErrorMessage("Firebase not initialized. Please restart the app.");
        setState(() => _loading = false);
        return;
      }

      // Verify Firebase Auth is available
      try {
        final auth = FirebaseAuth.instance;
        print('✅ Firebase Auth instance verified: ${auth.app.name}');
      } catch (e) {
        print('❌ Firebase Auth check failed: $e');
        _showErrorMessage(
            "Firebase authentication is not available. Please restart the app.");
        setState(() => _loading = false);
        return;
      }

      // Create user in Firebase Authentication
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 30));

      // Wait a moment for Firebase to fully process the user data
      await Future.delayed(const Duration(milliseconds: 1000));

      // Get user ID safely without accessing properties that might cause type cast errors
      String? userId;
      try {
        // Try to get user ID without triggering type cast issues
        final auth = FirebaseAuth.instance;
        final user = auth.currentUser;
        if (user != null) {
          // Access uid in a try-catch to handle potential type cast errors
          try {
            userId = user.uid;
          } catch (uidError) {
            print('⚠️ Could not access user ID: $uidError');
            // Try alternative method - use email as identifier temporarily
            userId = null;
          }
        }
      } catch (userAccessError) {
        print('⚠️ Error accessing user: $userAccessError');
        userId = null;
      }

      if (userId == null) {
        // User was created but we can't access the ID - still proceed with success
        print('✅ Firebase Auth user created (ID not accessible)');
      } else {
        print('✅ Firebase Auth user created: $userId');

        // Save user details in Firestore (non-blocking - don't fail registration if this fails)
        try {
          await FirebaseFirestore.instance.collection("users").doc(userId).set({
            "name": name,
            "email": email,
            "uid": userId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          }, SetOptions(merge: false));

          print('✅ Firestore user data saved successfully');
        } on FirebaseException catch (firestoreError) {
          print(
              '⚠️ Firestore Error (non-critical): ${firestoreError.code} - ${firestoreError.message}');
          // Continue with registration - Firestore save is not critical
        } catch (firestoreError) {
          print('⚠️ Firestore Error (non-critical): $firestoreError');
          // Continue with registration - Firestore save is not critical
        }

        // Try to update display name (non-critical, so we don't fail if it errors)
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.updateDisplayName(name);
            print('✅ Display name updated');
          }
        } catch (displayNameError) {
          print('⚠️ Could not update display name: $displayNameError');
          // Continue anyway - this is not critical
        }
      }

      // Clear form fields
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      print('❌ Stack trace: $stackTrace');
      _handleFirebaseError(e);
    } on TimeoutException catch (e, stackTrace) {
      print('❌ Timeout Error: $e');
      print('❌ Stack trace: $stackTrace');
      _showErrorMessage(
          "Request timed out. Please check your internet connection and try again.");
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');

      // Handle specific Pigeon type cast error
      String errorString = e.toString();
      if (errorString.contains('PigeonUserDetails') ||
          errorString.contains('not a subtype') ||
          errorString.contains('type cast')) {
        // This is a Firebase internal error - registration might have actually succeeded
        print(
            '⚠️ Pigeon type cast error detected - checking if registration succeeded');

        // Wait a bit and check if user is actually created
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final auth = FirebaseAuth.instance;
          if (auth.currentUser != null) {
            print('✅ Registration actually succeeded despite error');
            // Clear form fields
            _nameController.clear();
            _emailController.clear();
            _passwordController.clear();
            if (mounted) {
              _showSuccessDialog();
            }
            return; // Exit early - registration was successful
          }
        } catch (checkError) {
          print('❌ Error checking registration status: $checkError');
        }

        _showErrorMessage(
            "Registration completed but encountered an internal error. Please try logging in or restart the app.");
      } else {
        // Provide more specific error message for other errors
        String errorMsg = "An unexpected error occurred.";
        if (errorString.contains('PlatformException')) {
          errorMsg =
              "Platform error. Please ensure Firebase is properly configured.";
        } else if (errorString.contains('network')) {
          errorMsg = "Network error. Please check your internet connection.";
        } else if (errorString.contains('permission')) {
          errorMsg = "Permission denied. Please check Firebase permissions.";
        } else {
          errorMsg =
              "Error: ${errorString.length > 100 ? errorString.substring(0, 100) + '...' : errorString}";
        }
        _showErrorMessage(errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'weak-password':
        errorMessage =
            "The password provided is too weak. Please use a stronger password.";
        break;
      case 'email-already-in-use':
        errorMessage =
            "An account already exists for that email. Please login instead.";
        break;
      case 'invalid-email':
        errorMessage =
            "The email address is not valid. Please check your email.";
        break;
      case 'invalid-credential':
        errorMessage =
            "Invalid credentials. Please check your email and password format.";
        break;
      case 'operation-not-allowed':
        errorMessage =
            "Email/password accounts are not enabled. Please contact support.";
        break;
      case 'network-request-failed':
        errorMessage = "Network error. Please check your internet connection.";
        break;
      case 'too-many-requests':
        errorMessage = "Too many attempts. Please try again later.";
        break;
      default:
        errorMessage = e.message ?? "Registration failed. Please try again.";
    }
    _showErrorMessage(errorMessage);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Success!',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, color: Colors.green, size: 48),
              SizedBox(height: 16),
              Text(
                'Registration Completed Successfully!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You can now login with your credentials.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
              child: const Text(
                'Go to Login',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        );
      },
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            Container(color: Colors.black),
          Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.9),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.grey.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/logo.png'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Create Account",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 5),
                      const Text("Join our fashion community",
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 25),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Full Name",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.person, color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email address';
                          }
                          final emailRegex =
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.email, color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onRegisterPressed(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey),
                            onPressed: _togglePasswordVisibility,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.black, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Password must be at least 6 characters long",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: _loading ? null : _onRegisterPressed,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 55,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _loading
                                  ? [Colors.grey, Colors.grey]
                                  : [Colors.black, Colors.black87],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _loading
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "CREATE ACCOUNT",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? ",
                              style: TextStyle(color: Colors.grey)),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()));
                                  },
                            child: Text(
                              "SIGN IN",
                              style: TextStyle(
                                color: _loading ? Colors.grey : Colors.black,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
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
    );
  }
}
