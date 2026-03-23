import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';

class AnalysisResult {
  final bool isDefective;
  final double score;
  final double confidence;
  final String message;
  final Color color;

  AnalysisResult({
    required this.isDefective,
    required this.score,
    required this.confidence,
    required this.message,
    required this.color,
  });

  @override
  String toString() =>
      'AnalysisResult(message: $message, confidence: ${(confidence * 100).toStringAsFixed(2)}%, score: $score)';
}

class FabricClassifierService {
  static final FabricClassifierService _instance =
      FabricClassifierService._internal();
  factory FabricClassifierService() => _instance;
  FabricClassifierService._internal();

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/clean_fabric_classifier.tflite',
      );
      print("✅ Fabric Classifier Model Loaded");
    } catch (e) {
      print("❌ Error loading Fabric Classifier Model: $e");
    }
  }

  Future<AnalysisResult> classify(File imageFile) async {
    if (_interpreter == null) {
      print("⚠️ Interpreter not loaded, attempting to load...");
      await loadModel();
      if (_interpreter == null) throw Exception("Model not loaded");
    }

    try {
      // 1. Read and decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        throw Exception("Invalid image");
      }

      // 2. Preprocess: Resize to 224x224
      img.Image resizedImage =
          img.copyResize(originalImage, width: 224, height: 224);

      // 3. Create FLOAT32 buffer for input - [1, 224, 224, 3]
      final input = Float32List(1 * 224 * 224 * 3);
      int index = 0;

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);

          input[index++] = pixel.r.toDouble() / 255.0;
          input[index++] = pixel.g.toDouble() / 255.0;
          input[index++] = pixel.b.toDouble() / 255.0;
        }
      }

      // 4. Prepare nested List for output - [1, 1]
      var output = List.generate(1, (_) => List.filled(1, 0.0));

      // 5. Run inference
      _interpreter!.run(
        input.buffer.asFloat32List().reshape([1, 224, 224, 3]),
        output,
      );

      final score = output[0][0];

      bool isFabric = score < 0.5;

      print("--- Fabric Analysis Debug ---");
      print("RAW OUTPUT ARRAY: $output");
      print("Final Prediction Score: $score");

      if (isFabric) {
        return AnalysisResult(
          isDefective: false,
          score: score,
          confidence: 1.0 - score,
          message: "✅ FABRIC DETECTED",
          color: Colors.green,
        );
      } else {
        return AnalysisResult(
          isDefective: true,
          score: score,
          confidence: score,
          message: "❌ NON-FABRIC",
          color: Colors.red,
        );
      }
    } catch (e) {
      print("❌ Fabric classification failed: $e");
      return AnalysisResult(
        isDefective: true,
        score: 0.0,
        confidence: 0.0,
        message: "Unknown (Error)",
        color: Colors.red,
      );
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
