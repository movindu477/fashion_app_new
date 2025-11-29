import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:async';
import 'reg.dart';
import 'homepage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late VideoPlayerController _videoController;
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
      _videoController = VideoPlayerController.asset('assets/images/login.mp4');
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    setState(() => _loading = true);

    try {
      print('🔐 Attempting to login with: $email');

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

      // Attempt login with Firebase
      // Don't store UserCredential to avoid type cast issues
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 30));

      // Wait a moment for Firebase to fully process the user data
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check if user exists without accessing properties that might cause type cast errors
      try {
        // Simply check if currentUser exists - don't access any properties yet
        final auth = FirebaseAuth.instance;
        final hasUser = auth.currentUser != null;

        if (hasUser) {
          print('✅ Login successful - redirecting to homepage');

          // Clear form fields
          _emailController.clear();
          _passwordController.clear();

          // Navigate directly to homepage immediately
          if (mounted) {
            _navigateToHome();
          }
        } else {
          throw Exception('Login succeeded but no user found');
        }
      } catch (userCheckError) {
        print('⚠️ Error checking user: $userCheckError');
        // Even if we can't verify user, the sign-in succeeded
        // Clear form fields
        _emailController.clear();
        _passwordController.clear();

        // Navigate directly to homepage immediately
        if (mounted) {
          _navigateToHome();
        }
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
        // This is a Firebase internal error - login might have actually succeeded
        print(
            '⚠️ Pigeon type cast error detected - checking if login succeeded');

        // Wait a bit and check if user is actually logged in
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final auth = FirebaseAuth.instance;
          if (auth.currentUser != null) {
            print(
                '✅ Login actually succeeded despite error - redirecting to homepage');
            // Clear form fields
            _emailController.clear();
            _passwordController.clear();
            if (mounted) {
              _navigateToHome();
            }
            return; // Exit early - login was successful
          }
        } catch (checkError) {
          print('❌ Error checking login status: $checkError');
        }

        _showErrorMessage(
            "Login completed but encountered an internal error. Please try logging in again or restart the app.");
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
      case 'user-not-found':
        errorMessage =
            "No account found with this email. Please register first.";
        break;
      case 'wrong-password':
        errorMessage = "Incorrect password. Please try again.";
        break;
      case 'invalid-email':
        errorMessage = "The email address is not valid.";
        break;
      case 'invalid-credential':
        errorMessage =
            "The email or password is incorrect. Please check your credentials and try again.";
        break;
      case 'user-disabled':
        errorMessage =
            "This account has been disabled. Please contact support.";
        break;
      case 'too-many-requests':
        errorMessage = "Too many failed attempts. Please try again later.";
        break;
      case 'network-request-failed':
        errorMessage = "Network error. Please check your internet connection.";
        break;
      case 'operation-not-allowed':
        errorMessage =
            "Email/password accounts are not enabled. Please contact support.";
        break;
      case 'invalid-verification-code':
        errorMessage = "Invalid verification code.";
        break;
      case 'invalid-verification-id':
        errorMessage = "Invalid verification ID.";
        break;
      default:
        errorMessage = e.message ?? "Login failed. Please try again.";
    }
    _showErrorMessage(errorMessage);
  }

  void _navigateToHome() {
    if (!mounted) return;

    try {
      // Navigate to homepage and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false, // Remove all previous routes
      );
      print('✅ Navigation to HomePage completed');
    } catch (e) {
      print('❌ Navigation error: $e');
      // Retry navigation if it fails
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
            );
          } catch (retryError) {
            print('❌ Retry navigation error: $retryError');
          }
        }
      });
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
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
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.grey.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
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
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Login to continue",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 25),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegex =
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Email",
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
                        onFieldSubmitted: (_) => _onLoginPressed(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
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
                              color: Colors.grey,
                            ),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showErrorMessage(
                              "Forgot password feature coming soon!"),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: _loading ? null : _onLoginPressed,
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
                                    Text(
                                      "LOGIN",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward,
                                        color: Colors.white, size: 18),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[400])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text("OR",
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.grey[400])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ",
                              style: TextStyle(color: Colors.grey)),
                          GestureDetector(
                            onTap: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterPage()));
                                  },
                            child: Text(
                              "REGISTER",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _loading ? Colors.grey : Colors.black,
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
