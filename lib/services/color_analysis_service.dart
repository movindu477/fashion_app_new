import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';

class ColorAnalysisService {
  /// Extracts dominant colors from an image file path.
  /// Uses pixel sampling, filtering for distinct colors, and isolates for performance.
  static Future<List<Map<String, int>>> getDominantColors(String imagePath,
      {int sampleStep = 10}) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) return [];

      final Uint8List bytes = await imageFile.readAsBytes();

      // Run intensive processing in a background Isolate
      return await compute(_processImage, {
        'bytes': bytes,
        'sampleStep': sampleStep,
      });
    } catch (e) {
      debugPrint("Error in ColorAnalysisService: $e");
      return [];
    }
  }

  /// Internal processing logic for compute()
  static List<Map<String, int>> _processImage(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int sampleStep = params['sampleStep'];

    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return [];

    final Map<String, int> colorCounts = {};

    // 1. Sample pixels and count frequencies
    for (int y = 0; y < image.height; y += sampleStep) {
      for (int x = 0; x < image.width; x += sampleStep) {
        final img.Pixel pixel = image.getPixel(x, y);

        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Round to nearest 5 to group slightly similar colors during initial count
        final int rr = (r / 5).round() * 5;
        final int gg = (g / 5).round() * 5;
        final int bb = (b / 5).round() * 5;

        final String key = "$rr,$gg,$bb";
        colorCounts[key] = (colorCounts[key] ?? 0) + 1;
      }
    }

    // 2. Sort by frequency
    final sortedEntries = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Map<String, int>> distinctColors = [];

    // 3. Filter for distinct colors (Euclidean distance > threshold)
    for (var entry in sortedEntries) {
      if (distinctColors.length >= 5) break; // Get up to 5 colors

      final parts = entry.key.split(',');
      final int r = int.parse(parts[0]);
      final int g = int.parse(parts[1]);
      final int b = int.parse(parts[2]);

      bool isTooSimilar = false;
      for (var existing in distinctColors) {
        final double distance = sqrt(pow(r - existing['r']!, 2) +
            pow(g - existing['g']!, 2) +
            pow(b - existing['b']!, 2));

        if (distance < 45) {
          // Threshold for "looking different"
          isTooSimilar = true;
          break;
        }
      }

      if (!isTooSimilar) {
        distinctColors.add({"r": r, "g": g, "b": b});
      }
    }

    return distinctColors;
  }

  /// Converts RGB map to Flutter Color
  static Color mapToColor(Map<String, int> rgb) {
    return Color.fromARGB(255, rgb['r']!, rgb['g']!, rgb['b']!);
  }

  /// Converts RGB to Hex String
  static String rgbToHex(Map<String, int> rgb) {
    return '#${rgb['r']!.toRadixString(16).padLeft(2, '0')}${rgb['g']!.toRadixString(16).padLeft(2, '0')}${rgb['b']!.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }
}
