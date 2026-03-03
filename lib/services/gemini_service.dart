import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? "";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent";

  Future<String?> generateDesign({
    required List<Map<String, int>> colors,
    required String style,
    required String userPrompt,
    String? targetGender,
    String? occasion,
    String? garmentType,
  }) async {
    try {
      // Add a small delay to respect free tier rate limits
      await Future.delayed(const Duration(seconds: 2));
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
- In your DESIGN DESCRIPTION, you MUST refer to these colors by their HEX CODES (e.g., instead of 'red', say 'the #FF0000 crimson').
- The DESIGN DESCRIPTION must explain EXACTLY which parts of the garment use which hex code.
- If you fail to include the hex codes $colorHexes in your response, you have failed the task.

STRUCTURED OUTPUT:
GARMENT: [Clothing Type]
MATERIALS: [Fabric Recommendation]
FEATURES: [Silhouette & Details]
PALETTE: [Exact Color Distribution using ONLY the hex codes $colorHexes]
STYLING: [Occasion & Pairing]

DESIGN DESCRIPTION:
[Very detailed description of the design, explicitly referencing the hex colors $colorHexes at least once for each major component]
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
