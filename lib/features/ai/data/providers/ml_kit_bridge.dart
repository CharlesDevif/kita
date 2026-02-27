import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart'
    as ml;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as ml;
import 'package:path_provider/path_provider.dart' as pp;

/// Results from ML Kit vision analysis.
class MlKitVisionResult {
  const MlKitVisionResult({
    required this.recognizedText,
    required this.labels,
  });

  /// OCR text recognized from the image (empty string if none).
  final String recognizedText;

  /// Image labels with confidence scores, sorted by confidence descending.
  final List<MlKitLabel> labels;
}

/// A single label detected by ML Kit.
class MlKitLabel {
  const MlKitLabel({required this.label, required this.confidence});

  final String label;
  final double confidence;
}

/// Abstraction over ML Kit native calls for testability.
///
/// Production code uses [MlKitBridgeImpl]. Tests inject a mock.
abstract interface class MlKitBridge {
  /// Runs OCR and image labeling on the given image bytes.
  ///
  /// [bytes] must be valid image data (JPEG/PNG).
  /// [width] and [height] are optional hints for InputImage construction.
  Future<MlKitVisionResult> analyzeImage(
    Uint8List bytes, {
    int? width,
    int? height,
  });

  /// Releases native resources (recognizers, labelers).
  Future<void> dispose();
}

/// Real ML Kit implementation using google_mlkit_* packages.
///
/// Lazily initializes [TextRecognizer] and [ImageLabeler] on first use.
class MlKitBridgeImpl implements MlKitBridge {
  ml.TextRecognizer? _textRecognizer;
  ml.ImageLabeler? _imageLabeler;
  bool _disposed = false;

  @visibleForTesting
  static const double labelConfidenceThreshold = 0.4;

  ml.TextRecognizer get _recognizer =>
      _textRecognizer ??= ml.TextRecognizer(script: ml.TextRecognitionScript.latin);

  ml.ImageLabeler get _labeler => _imageLabeler ??= ml.ImageLabeler(
        options: ml.ImageLabelerOptions(
          confidenceThreshold: labelConfidenceThreshold,
        ),
      );

  @override
  Future<MlKitVisionResult> analyzeImage(
    Uint8List bytes, {
    int? width,
    int? height,
  }) async {
    if (_disposed) {
      throw StateError('MlKitBridge has been disposed');
    }

    final inputImage = await _buildInputImage(bytes, width: width, height: height);

    // Run OCR and labeling in parallel.
    final results = await Future.wait([
      _recognizer.processImage(inputImage),
      _labeler.processImage(inputImage),
    ]);

    final recognizedText = (results[0] as ml.RecognizedText).text;
    final imageLabels = (results[1] as List<ml.ImageLabel>)
        .map((l) => MlKitLabel(label: l.label, confidence: l.confidence))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return MlKitVisionResult(
      recognizedText: recognizedText,
      labels: imageLabels,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _textRecognizer?.close();
    await _imageLabeler?.close();
    _textRecognizer = null;
    _imageLabeler = null;
  }

  /// Builds an [InputImage] from the given bytes.
  ///
  /// If [width] and [height] are provided, the bytes are treated as raw
  /// pixel data (BGRA8888). Otherwise, the bytes are assumed to be encoded
  /// (JPEG/PNG) and are written to a temp file for ML Kit to decode natively
  /// via [InputImage.fromFilePath].
  Future<ml.InputImage> _buildInputImage(
    Uint8List bytes, {
    int? width,
    int? height,
  }) async {
    // Raw pixel data with known dimensions → fromBytes.
    if (width != null && height != null) {
      return ml.InputImage.fromBytes(
        bytes: bytes,
        metadata: ml.InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: ml.InputImageRotation.rotation0deg,
          format: ml.InputImageFormat.bgra8888,
          bytesPerRow: width * 4,
        ),
      );
    }

    // Encoded image (JPEG/PNG) → write to temp file and use fromFilePath.
    // ML Kit's fromBytes expects raw pixel data, not encoded formats.
    final tempDir = await pp.getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/mlkit_input_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);
    return ml.InputImage.fromFilePath(tempFile.path);
  }
}
