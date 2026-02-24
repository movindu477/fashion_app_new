import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Provided Gemini API Key
  static const String _apiKey = "AIzaSyA13cMFlOXIOdbzbmJUTX731oBmA-InuS0";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent";

  Future<String?> generateDesign({
    required List<Map<String, int>> colors,
    required String style,
    required String userPrompt,
    String? targetGender,
    String? occasion,
    String? garmentType,
  }) async {
    try {
      final colorHexes = colors.map((c) {
        final r = c['r']!.toRadixString(16).padLeft(2, '0');
        final g = c['g']!.toRadixString(16).padLeft(2, '0');
        final b = c['b']!.toRadixString(16).padLeft(2, '0');
        return '#${r}${g}${b}'.toUpperCase();
      }).join(', ');

      final prompt = """
You are a professional fashion designer.

TASK:
Generate a detailed and creative fashion design concept based on the specifications below.

SPECIFICATIONS:
Dominant Color Palette: $colorHexes
Design Style: $style
Target Gender: ${targetGender ?? 'Unisex'}
Occasion: ${occasion ?? 'Any'}
Garment Type: ${garmentType ?? 'Dress'}
Additional Instructions: ${userPrompt.isEmpty ? 'N/A' : userPrompt}

STRICT REQUIREMENT:
- You MUST explicitly use ONLY these EXACT HEX COLORS from the Dominant Color Palette: $colorHexes.
- Do NOT use generic color names like 'blue' or 'red' alone; always refer to them by their specific hex codes in your DESIGN DESCRIPTION.
- The DESIGN DESCRIPTION must describe how these specific colors are applied to different parts of the garment in detail.
- Ensure the description is extremely vivid so a text-to-image AI can accurately visualize these EXACT colors.

STRUCTURED OUTPUT:
GARMENT: [Clothing Type]
MATERIALS: [Fabric Recommendation]
FEATURES: [Silhouette & Details]
PALETTE: [Exact Color Distribution using ONLY $colorHexes]
STYLING: [Occasion & Pairing]

DESIGN DESCRIPTION:
[Detailed description of the design incorporating the MANDATORY hex colors $colorHexes]
""";

      print("🚀 [Gemini] Status: Requesting designer concept...");

      final response = await http
          .post(
            Uri.parse("$_baseUrl?key=$_apiKey"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt}
                  ]
                }
              ],
              "generationConfig": {
                "temperature": 0.8,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048,
              }
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw "No design generated. The prompt might have been blocked by safety filters.";
        }

        final content = candidates[0]['content'];
        if (content == null || content['parts'] == null) {
          throw "Empty content response from AI.";
        }

        final parts = content['parts'] as List;
        String? textResult;

        for (var part in parts) {
          if (part is Map && part.containsKey('text')) {
            textResult = (textResult ?? "") + part['text'];
          }
        }

        return textResult;
      } else {
        String msg = "Design generation failed";
        try {
          final errorJson = jsonDecode(response.body);
          msg =
              errorJson['error']['message'] ?? "Error: ${response.statusCode}";
        } catch (_) {
          msg = "Status Code: ${response.statusCode}";
        }
        throw msg;
      }
    } catch (e) {
      print("❌ [Gemini] Exception: $e");
      rethrow;
    }
  }
}
