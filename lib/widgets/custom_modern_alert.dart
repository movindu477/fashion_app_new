import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum CustomAlertType { success, error }

class CustomModernAlert extends StatelessWidget {
  final String title;
  final String message;
  final CustomAlertType type;
  final VoidCallback onBtnTap;
  final String btnText;

  const CustomModernAlert({
    Key? key,
    required this.title,
    required this.message,
    required this.type,
    required this.onBtnTap,
    this.btnText = "CONTINUE",
  }) : super(key: key);

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    required CustomAlertType type,
    String? btnText,
    VoidCallback? onBtnTap,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomModernAlert(
        title: title,
        message: message,
        type: type,
        btnText: btnText ?? (type == CustomAlertType.success ? "CONTINUE" : "GO BACK"),
        onBtnTap: onBtnTap ?? () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = type == CustomAlertType.success ? const Color(0xFF00C853) : const Color(0xFFFF1744);
    final icon = type == CustomAlertType.success ? Icons.check_rounded : Icons.priority_high_rounded;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Accent Graphic
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background curve
                  Positioned(
                    top: -40,
                    child: Container(
                      width: 280,
                      height: 160,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(140),
                      ),
                    ),
                  ),
                  // Icon Circle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 3),
                    ),
                    child: Icon(icon, color: color, size: 40),
                  ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.elasticOut),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onBtnTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        btnText.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ],
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn(),
    );
  }
}
