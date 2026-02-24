import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../../ai/domain/image_data.dart';

/// Strips all EXIF metadata (GPS, device info, date, etc.) from images.
///
/// Protects user privacy by ensuring no identifying metadata is sent
/// to cloud AI services.
class ExifStripper {
  static final _log = KitaLogger('IO');

  /// Strips all EXIF metadata from the given [imageData].
  ///
  /// Returns a new [ImageData] with the same image content but no EXIF.
  /// Supports JPEG and PNG formats.
  static Result<ImageData> strip(ImageData imageData) {
    try {
      final decoded = img.decodeImage(imageData.bytes);
      if (decoded == null) {
        _log.warning('Could not decode image for EXIF stripping');
        return const Result.failure(
          UnexpectedFailure(
            logMessage: 'Failed to decode image for EXIF stripping',
          ),
        );
      }

      // Clear all EXIF metadata.
      decoded.exif.clear();

      // Detect format from bytes to preserve original encoding.
      // JPEG starts with 0xFF 0xD8, PNG with 0x89 0x50 0x4E 0x47.
      final bytes = imageData.bytes;
      final isPng = bytes.length >= 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;

      List<int> cleanBytes;
      String mimeType;
      if (isPng) {
        cleanBytes = img.encodePng(decoded);
        mimeType = 'image/png';
      } else {
        // Default to JPEG for JPEG and other/unknown formats.
        cleanBytes = img.encodeJpg(decoded, quality: 95);
        mimeType = 'image/jpeg';
      }

      _log.info('EXIF stripped: ${imageData.bytes.length} -> ${cleanBytes.length} bytes');

      return Result.success(ImageData(
        bytes: Uint8List.fromList(cleanBytes),
        mimeType: mimeType,
        width: decoded.width,
        height: decoded.height,
      ));
    } catch (e, stack) {
      _log.error('EXIF strip failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'EXIF strip failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }
}
