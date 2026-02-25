import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FabricClassificationResult {
  final bool isFabric;
  final double score;
  final double confidence;
  final String label;

  FabricClassificationResult({
    required this.isFabric,
    required this.score,
    required this.confidence,
    required this.label,
  });

  @override
  String toString() =>
      'FabricClassificationResult(label: $label, confidence: ${(confidence * 100).toStringAsFixed(2)}%, score: $score)';
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
        'assets/models/fabric_classifier_model.tflite',
      );
      print("✅ Fabric Classifier Model Loaded");
    } catch (e) {
      print("❌ Error loading Fabric Classifier Model: $e");
    }
  }

  Future<FabricClassificationResult> classify(File imageFile) async {
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

          // Sending raw pixel values (0-255) as float32
          // The model's internal Rescaling(1./255) will handle normalization
          input[index++] = pixel.r.toDouble();
          input[index++] = pixel.g.toDouble();
          input[index++] = pixel.b.toDouble();
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

      // Calculate confidence and label
      // alphabetical: 0 = fabric/clothing, 1 = non_fabric/non_clothing
      bool isFabricResult = score < 0.5;
      double confidence = isFabricResult ? (1.0 - score) : score;
      String label = isFabricResult ? "Fabric" : "Not Fabric";

      print("--- Fabric Analysis Debug ---");
      print("RAW OUTPUT ARRAY: $output");
      print("Final Prediction Score: $score");
      print("Label: $label");

      return FabricClassificationResult(
        isFabric: isFabricResult,
        score: score,
        confidence: confidence,
        label: label,
      );
    } catch (e) {
      print("❌ Fabric classification failed: $e");
      return FabricClassificationResult(
        isFabric: true,
        score: 0.0,
        confidence: 0.5,
        label: "Unknown (Error)",
      );
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
