import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_genai_image_description/google_mlkit_genai_image_description.dart';
// FeatureStatus is not exported from the barrel file, import src directly.
// ignore: implementation_imports
import 'package:google_mlkit_genai_image_description/src/image_describer.dart'
    show FeatureStatus;
import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../../core/utils/logger.dart';

/// Status of Gemini Nano availability on the device.
enum GeminiNanoStatus {
  /// Model is ready for inference.
  available,

  /// Model can be downloaded but is not yet on device.
  downloadable,

  /// Model is currently downloading.
  downloading,

  /// Model is not supported on this device (no AICore).
  unavailable,
}

/// Result from Gemini Nano image description.
class GeminiNanoDescriptionResult {
  const GeminiNanoDescriptionResult({
    required this.description,
  });

  /// The generated description text (English only for now).
  final String description;
}

/// Abstraction over Gemini Nano (ML Kit GenAI Image Description API).
///
/// Production code uses [GeminiNanoBridgeImpl]. Tests inject a mock.
abstract interface class GeminiNanoBridge {
  /// Check if Gemini Nano image description is available on this device.
  Future<GeminiNanoStatus> checkAvailability();

  /// Trigger model download if status is [GeminiNanoStatus.downloadable].
  ///
  /// Returns true if download was initiated or model is already available.
  Future<bool> downloadModel();

  /// Generate a description of the given image.
  ///
  /// [bytes] must be valid encoded image data (JPEG/PNG).
  /// Returns the description or throws on failure.
  Future<GeminiNanoDescriptionResult> describeImage(Uint8List bytes);

  /// Release native resources.
  Future<void> dispose();
}

/// Real implementation using google_mlkit_genai_image_description.
///
/// Writes image bytes to a temp file (required by the native API which
/// expects a file path to construct a Bitmap), runs inference via Gemini Nano,
/// and returns the description text.
class GeminiNanoBridgeImpl implements GeminiNanoBridge {
  static final _log = KitaLogger('AI.GeminiNano');

  ImageDescriber? _describer;
  bool _disposed = false;

  @visibleForTesting
  static const int maxRetries = 1;

  ImageDescriber get _getOrCreateDescriber {
    return _describer ??= ImageDescriber();
  }

  @override
  Future<GeminiNanoStatus> checkAvailability() async {
    if (_disposed) return GeminiNanoStatus.unavailable;

    try {
      final status = await _getOrCreateDescriber.checkFeatureStatus();
      _log.debug('Gemini Nano feature status: ${status.name}');
      return _mapStatus(status);
    } on Exception catch (e) {
      _log.warning('Failed to check Gemini Nano availability', error: e);
      return GeminiNanoStatus.unavailable;
    }
  }

  @override
  Future<bool> downloadModel() async {
    if (_disposed) return false;

    try {
      final status = await _getOrCreateDescriber.checkFeatureStatus();
      if (status == FeatureStatus.available) return true;
      if (status == FeatureStatus.downloadable) {
        _log.info('Initiating Gemini Nano model download');
        await _getOrCreateDescriber.downloadFeature();
        return true;
      }
      return false;
    } on Exception catch (e) {
      _log.warning('Failed to download Gemini Nano model', error: e);
      return false;
    }
  }

  @override
  Future<GeminiNanoDescriptionResult> describeImage(Uint8List bytes) async {
    if (_disposed) {
      throw StateError('GeminiNanoBridge has been disposed');
    }

    // The ML Kit GenAI Image Description API uses InputImage internally.
    // Write bytes to a temp file and use InputImage.fromFilePath, then
    // pass the serialized InputImage to runInference.
    final tempFile = await _writeTempFile(bytes);

    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final description =
          await _getOrCreateDescriber.runInference(inputImage.toJson());

      if (description.isEmpty) {
        _log.warning('Gemini Nano returned empty description');
        throw Exception('Empty description returned by Gemini Nano');
      }

      _log.info('Gemini Nano description generated');
      return GeminiNanoDescriptionResult(description: description);
    } finally {
      // Clean up temp file
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } on Exception catch (e) {
        _log.warning('Failed to delete temp file', error: e);
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _describer?.close();
    _describer = null;
  }

  /// Write image bytes to a temporary file for InputImage.fromFilePath.
  Future<File> _writeTempFile(Uint8List bytes) async {
    final tempDir = await path_provider.getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${tempDir.path}/kita_nano_$timestamp.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  GeminiNanoStatus _mapStatus(FeatureStatus status) {
    return switch (status) {
      FeatureStatus.available => GeminiNanoStatus.available,
      FeatureStatus.downloadable => GeminiNanoStatus.downloadable,
      FeatureStatus.downloading => GeminiNanoStatus.downloading,
      FeatureStatus.unavailable => GeminiNanoStatus.unavailable,
    };
  }
}
