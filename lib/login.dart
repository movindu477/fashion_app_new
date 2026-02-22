import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';
import 'homepage.dart';
import 'package:quickalert/quickalert.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // Common Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Register specific
  final TextEditingController _nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _isLogin = true; // Toggle state

  late AnimationController _fadeController;
  late AnimationController _bgController;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;
  late Animation<Color?> _color3;

  @override
  void initState() {
    super.initState();
    _checkFirebaseInitialization();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeController.forward();

    // Smooth animated background
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _color1 = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF0D1B2A), end: const Color(0xFF1A0533)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF1A0533), end: const Color(0xFF0D1B2A)),
        weight: 1,
      ),
    ]).animate(_bgController);

    _color2 = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF16213E), end: const Color(0xFF3D0C5E)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF3D0C5E), end: const Color(0xFF16213E)),
        weight: 1,
      ),
    ]).animate(_bgController);

    _color3 = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF0F3460), end: const Color(0xFF7B1450)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
            begin: const Color(0xFF7B1450), end: const Color(0xFF0F3460)),
        weight: 1,
      ),
    ]).animate(_bgController);
  }

  Future<void> _checkFirebaseInitialization() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('Firebase check error: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _fadeController.reverse().then((_) {
      setState(() {
        _isLogin = !_isLogin;
      });
      _fadeController.forward();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _performLogin();
      } else {
        await _performRegister();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performLogin() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    _onAuthSuccess('Welcome Back!', 'Login Successful');
  }

  Future<void> _performRegister() async {
    final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final user = userCredential.user;
    if (user != null) {
      await user.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "uid": user.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
    _onAuthSuccess('Welcome!', 'Account Created Successfully');
  }

  void _onAuthSuccess(String title, String text) async {
    if (!mounted) return;
    await QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title,
      text: text,
      autoCloseDuration: const Duration(seconds: 2),
      showConfirmBtn: false,
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: 'Failed',
      text: message,
      confirmBtnColor: const Color(0xFFCCFF00),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _color1.value ?? const Color(0xFF0D1B2A),
                      _color2.value ?? const Color(0xFF16213E),
                      _color3.value ?? const Color(0xFF0F3460),
                    ],
                  ),
                ),
              );
            },
          ),

          // Subtle animated blobs for depth
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Positioned(
                top: -80,
                right: -60,
                child: Opacity(
                  opacity: 0.18,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        const Color(0xFFCCFF00),
                        const Color(0xFF9B59B6),
                        _bgController.value,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Positioned(
                bottom: -60,
                left: -40,
                child: Opacity(
                  opacity: 0.14,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        const Color(0xFF3498DB),
                        const Color(0xFFCCFF00),
                        _bgController.value,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Header — logo only, no skip
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 52,
                      width: 52,
                      fit: BoxFit.cover,
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(),
                  const SizedBox(height: 40),

                  // Animated title — changes with toggle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Align(
                      key: ValueKey(_isLogin),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isLogin ? 'Welcome\nBack.' : 'Start\nCreating.',
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 14),

                  // Animated subtitle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Text(
                      key: ValueKey('sub_$_isLogin'),
                      _isLogin
                          ? 'Your AI fashion studio is waiting.\nDesign, explore, and inspire.'
                          : 'Join Texora and bring your\nfashion ideas to life with AI.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white54,
                        height: 1.6,
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                  const SizedBox(height: 36),

                  // 3. FORM CARD
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOGGLE SWITCH
                          Container(
                            height: 55,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                _buildToggleButton('Log in', _isLogin),
                                _buildToggleButton('Sign up', !_isLogin),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 500.ms)
                              .slideX(begin: 0.1, end: 0),
                          const SizedBox(height: 32),

                          // FORM FIELDS
                          if (!_isLogin)
                            _buildInputField(
                              label: 'Full Name',
                              controller: _nameController,
                              icon: Icons.person_outline_rounded,
                              hint: 'John Doe',
                            )
                                .animate()
                                .fadeIn(delay: 600.ms)
                                .slideX(begin: 0.1, end: 0),
                          if (!_isLogin) const SizedBox(height: 12),
                          _buildInputField(
                            label: 'Email',
                            controller: _emailController,
                            icon: Icons.email_outlined,
                            hint: 'sam.altman@gmail.com',
                          )
                              .animate()
                              .fadeIn(delay: 700.ms)
                              .slideX(begin: 0.1, end: 0),
                          const SizedBox(height: 20),
                          _buildInputField(
                            label: 'Password',
                            controller: _passwordController,
                            icon: Icons.key_outlined,
                            hint: '••••••••',
                            isPassword: true,
                          )
                              .animate()
                              .fadeIn(delay: 800.ms)
                              .slideX(begin: 0.1, end: 0),

                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 900.ms),

                          const SizedBox(height: 12),

                          // SUBMIT BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCCFF00),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      _isLogin ? 'Log in' : 'Create Account',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 1.seconds).scale(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: active ? null : _toggleMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: active ? Colors.black : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && _obscurePassword,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
              prefixIcon: Icon(icon, color: Colors.white38, size: 18),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              return null;
            },
          ),
        ),
      ],
    );
  }
}
