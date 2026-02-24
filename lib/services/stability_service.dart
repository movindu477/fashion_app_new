import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StabilityService {
  static const String _fallbackApiKey =
      "sk-CG6fRll0j7vkphcJAgWoeDoDeGjZXa1LZ4a5gqCLBLk89g7F";
  static const String _endpoint =
      "https://api.stability.ai/v2beta/stable-image/generate/sd3";
  static const String _balanceEndpoint =
      "https://api.stability.ai/v1/user/balance";

  /// Fetches the ACTUAL balance from Stability AI and updates Firestore
  Future<int> syncBalanceFromApi() async {
    try {
      final sysDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('system')
          .get();

      String activeKey = _fallbackApiKey;
      if (sysDoc.exists) {
        activeKey = sysDoc.data()?['stability_api_key'] ?? _fallbackApiKey;
      }

      final response = await http.get(
        Uri.parse(_balanceEndpoint),
        headers: {
          "Authorization": "Bearer $activeKey",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Stability returns credits as a double (e.g. 10.50). We round it for the UI.
        final double realCredits = (data['credits'] ?? 0.0).toDouble();
        final int roundedCredits = realCredits.floor();

        // Update the global balance in Firestore
        await FirebaseFirestore.instance
            .collection('app_settings')
            .doc('system')
            .set({
          'image_credits': roundedCredits,
        }, SetOptions(merge: true));

        return roundedCredits;
      }
      return 0;
    } catch (e) {
      print("❌ [Stability AI] Balance Sync Error: $e");
      return 0;
    }
  }

  Future<Uint8List?> generateFashionSketch(String concept,
      {required String targetGender, List<Map<String, int>>? colors}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Please sign in to generate designs.";

      // 1. Fetch Global Settings & User Credits
      final sysDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('system')
          .get();

      String activeKey = _fallbackApiKey;
      bool isEnabled = true;

      if (sysDoc.exists) {
        final data = sysDoc.data()!;
        activeKey = data['stability_api_key'] ?? _fallbackApiKey;
        isEnabled = data['isImageEnabled'] ?? true;
      }

      // Check Real-time balance instead of just cached numbers
      // This is for the owner/developer use case you mentioned
      int credits = sysDoc.data()?['image_credits'] ?? 0;

      // 2. Check credits and status
      if (!isEnabled) {
        throw "AI Image Generation is temporarily disabled.";
      }
      if (credits <= 0) {
        // One last check: try to sync before failing
        credits = await syncBalanceFromApi();
        if (credits <= 0) throw "CREDITS_EXHAUSTED";
      }

      String colorFocus = "";
      if (colors != null && colors.isNotEmpty) {
        final hexes = colors.take(5).map((c) {
          final r = c['r']!.toRadixString(16).padLeft(2, '0');
          final g = c['g']!.toRadixString(16).padLeft(2, '0');
          final b = c['b']!.toRadixString(16).padLeft(2, '0');
          return '#${r}${g}${b}'.toUpperCase();
        }).join(', ');
        colorFocus =
            "\nEXACT COLOR PALETTE: Use ONLY the following HEX codes as the dominant colors for the garment: $hexes. The sketch MUST reflect these specific analyzed fabric colors exactly.";
      }

      final refinedPrompt = """
Create a professional full-body fashion runway illustration for a $targetGender model based on the following design concept:

$concept
$colorFocus

The image must:
- Show a clearly identifiable $targetGender fashion model
- Match the $targetGender body type and silhouette conventions
- Be a clean white background
- Show realistic fabric folds and draping
- Emphasize garment silhouette
- Look like a high-end fashion portfolio sketch
- Be highly detailed and editorial style

No text. No watermark.
""";

      final request = http.MultipartRequest("POST", Uri.parse(_endpoint));
      request.headers.addAll({
        "Authorization": "Bearer $activeKey",
        "Accept": "application/json",
      });
      request.fields["prompt"] = refinedPrompt;
      request.fields["output_format"] = "png";
      request.fields["model"] = "sd3";

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Auto-sync after successful generation to keep balance fresh
        await syncBalanceFromApi();

        final data = jsonDecode(response.body);
        final base64Image = data["image"];
        return base64Image != null ? base64Decode(base64Image) : null;
      } else if (response.statusCode == 402) {
        await syncBalanceFromApi(); // Ensure we know we're at 0
        throw "CREDITS_EXHAUSTED";
      } else {
        throw "Generation failed: ${response.statusCode}";
      }
    } catch (e) {
      print("❌ [Stability AI] Exception: $e");
      rethrow;
    }
  }
}
