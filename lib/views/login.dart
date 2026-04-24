import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'homepage.dart';
import '../widgets/custom_modern_alert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  final bool startOnRegister;
  const LoginPage({super.key, this.startOnRegister = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late bool _isLogin;

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _rememberMe = false;

  // Register form
  final _regFormKey = GlobalKey<FormState>();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _obscureRegPassword = true;
  bool _obscureRegConfirm = true;
  bool _agreedToTerms = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startOnRegister;
    _checkFirebaseInitialization();
  }

  Future<void> _checkFirebaseInitialization() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase check error: $e');
    }
  }

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _switchTab(bool toLogin) {
    if (_isLogin == toLogin) return;
    setState(() => _isLogin = toLogin);
  }

  Future<void> _handleSubmit() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text.trim(),
      );
      _onAuthSuccess('Welcome Back!', 'Login Successful');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRegisterPressed() async {
    if (!_regFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms & Privacy to continue.');
      return;
    }
    setState(() => _loading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _regEmailCtrl.text.trim(),
        password: _regPasswordCtrl.text.trim(),
      );
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "email": _regEmailCtrl.text.trim(),
          "uid": user.uid,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
      if (mounted) {
        CustomModernAlert.show(
          context: context,
          type: CustomAlertType.success,
          title: 'Welcome!',
          message: 'Account Created Successfully',
          btnText: 'Log In Now',
          onBtnTap: () {
            Navigator.of(context).pop();
            setState(() => _isLogin = true);
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "name": user.displayName,
          "email": user.email,
          "uid": user.uid,
          "photoUrl": user.photoURL,
          "lastLogin": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _onAuthSuccess('Welcome!', 'Google Login Successful');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAuthSuccess(String title, String text) {
    if (!mounted) return;
    CustomModernAlert.show(
      context: context,
      type: CustomAlertType.success,
      title: title,
      message: text,
      onBtnTap: () {
        Navigator.pop(context);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    CustomModernAlert.show(
      context: context,
      type: CustomAlertType.error,
      title: 'Oops!',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Layer 1: full-screen background image ─────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: SizedBox(
              key: ValueKey(_isLogin),
              height: double.infinity,
              width: double.infinity,
              child: Image.asset(
                _isLogin
                    ? 'assets/images/login1.jpg'
                    : 'assets/images/register1.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // ── Layer 2: title + bottom card ──────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(height: 60), // Space at top for image visibility
                          // Hero title on the image
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                key: ValueKey(_isLogin),
                                _isLogin ? 'Welcome Back!' : 'Join Us Today!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // White card
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 24,
                                  offset: Offset(0, -6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(24, 22, 24, bottomPad + 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTabSwitcher().animate().fadeIn(delay: 80.ms),
                                  const SizedBox(height: 14),
                                  AnimatedCrossFade(
                                    firstChild: Form(
                                      key: _loginFormKey,
                                      child: _buildLoginFields(),
                                    ),
                                    secondChild: Form(
                                      key: _regFormKey,
                                      child: _buildRegisterFields(),
                                    ),
                                    crossFadeState: _isLogin
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    duration: const Duration(milliseconds: 350),
                                    firstCurve: Curves.easeInOut,
                                    secondCurve: Curves.easeInOut,
                                    sizeCurve: Curves.easeInOut,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGradientButton(
                                    text: _isLogin ? 'Log In' : 'Sign Up',
                                    onTap: _isLogin ? _handleSubmit : _onRegisterPressed,
                                    loading: _loading,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildDivider(),
                                  const SizedBox(height: 14),
                                  _buildGoogleButton(onTap: _handleGoogleSignIn),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => _switchTab(!_isLogin),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFF666666),
                                          ),
                                          children: [
                                            TextSpan(
                                              text: _isLogin
                                                  ? "Don't have an account? "
                                                  : "Already have an account? ",
                                            ),
                                            TextSpan(
                                              text: _isLogin ? "Sign Up" : "Log In",
                                              style: const TextStyle(
                                                color: Color(0xFFFF5200),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Layer 3: back button ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const SplashScreen()),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 20, color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _tab('Log In', isActive: _isLogin, onTap: () => _switchTab(true))),
          Expanded(child: _tab('Sign Up', isActive: !_isLogin, onTap: () => _switchTab(false))),
        ],
      ),
    );
  }

  Widget _tab(String label,
      {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFFF5200), Color(0xFFE64A19)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? Colors.white : const Color(0xFFAAAAAA),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Email'),
        const SizedBox(height: 6),
        _buildField(
          controller: _loginEmailCtrl,
          hint: 'Enter your email',
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 10),
        _fieldLabel('Password'),
        const SizedBox(height: 6),
        _buildField(
          controller: _loginPasswordCtrl,
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureLoginPassword,
          onToggle: () =>
              setState(() => _obscureLoginPassword = !_obscureLoginPassword),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) =>
                        setState(() => _rememberMe = v ?? false),
                    activeColor: const Color(0xFFFF5200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFFFF5200),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Email'),
        const SizedBox(height: 6),
        _buildField(
          controller: _regEmailCtrl,
          hint: 'Enter your email',
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 10),
        _fieldLabel('Password'),
        const SizedBox(height: 6),
        _buildField(
          controller: _regPasswordCtrl,
          hint: 'Create a password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureRegPassword,
          onToggle: () =>
              setState(() => _obscureRegPassword = !_obscureRegPassword),
        ),
        const SizedBox(height: 10),
        _fieldLabel('Confirm Password'),
        const SizedBox(height: 6),
        _buildField(
          controller: _regConfirmCtrl,
          hint: 'Re-enter your password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _obscureRegConfirm,
          onToggle: () =>
              setState(() => _obscureRegConfirm = !_obscureRegConfirm),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v != _regPasswordCtrl.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () =>
              setState(() => _agreedToTerms = !_agreedToTerms),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) =>
                      setState(() => _agreedToTerms = v ?? false),
                  activeColor: const Color(0xFFFF5200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFF888888)),
                  children: [
                    TextSpan(text: 'Agree To '),
                    TextSpan(
                      text: 'Terms & Privacy',
                      style: TextStyle(
                        color: Color(0xFFFF5200),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF444444),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && obscure,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Color(0xFF222222),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFBBBBBB),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFBBBBBB), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFFBBBBBB),
                    size: 18,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        validator:
            validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5200), Color(0xFFE64A19)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5200).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFEEEEEE))),
      ],
    );
  }

  Widget _buildGoogleButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google.jpg', height: 24, width: 24),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
