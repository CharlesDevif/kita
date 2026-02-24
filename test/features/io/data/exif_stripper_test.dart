import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/io/data/exif_stripper.dart';

void main() {
  group('ExifStripper', () {
    late ImageData imageWithExif;

    setUp(() {
      // Create a small test image with EXIF data.
      final image = img.Image(width: 10, height: 10);

      // Add some EXIF metadata (GPS, device info).
      image.exif.imageIfd['Make'] = 'TestDevice';
      image.exif.imageIfd['Model'] = 'TestModel';

      final bytes = img.encodeJpg(image);
      imageWithExif = ImageData(
        bytes: Uint8List.fromList(bytes),
        mimeType: 'image/jpeg',
        width: 10,
        height: 10,
      );
    });

    test('strip returns success with valid JPEG', () {
      final result = ExifStripper.strip(imageWithExif);
      expect(result.isSuccess, isTrue);
    });

    test('stripped image has no identifying EXIF metadata', () {
      final result = ExifStripper.strip(imageWithExif);

      result.when(
        success: (stripped) {
          // Decode the stripped image and check device-identifying EXIF is gone.
          final decoded = img.decodeImage(stripped.bytes);
          expect(decoded, isNotNull);

          // Device-identifying fields should be gone after strip + re-encode.
          expect(decoded!.exif.imageIfd['Make'], isNull);
          expect(decoded.exif.imageIfd['Model'], isNull);
        },
        failure: (_) => fail('Expected success'),
      );
    });

    test('stripped image preserves dimensions', () {
      final result = ExifStripper.strip(imageWithExif);

      result.when(
        success: (stripped) {
          expect(stripped.width, equals(10));
          expect(stripped.height, equals(10));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    test('stripped image has image/jpeg mimeType', () {
      final result = ExifStripper.strip(imageWithExif);

      result.when(
        success: (stripped) {
          expect(stripped.mimeType, equals('image/jpeg'));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    test('strip returns failure for invalid image data', () {
      final badImage = ImageData(
        bytes: Uint8List.fromList([0x00, 0x01, 0x02]),
      );
      final result = ExifStripper.strip(badImage);
      expect(result.isFailure, isTrue);
    });

    test('stripped image bytes are valid JPEG', () {
      final result = ExifStripper.strip(imageWithExif);

      result.when(
        success: (stripped) {
          expect(stripped.bytes.length, greaterThan(0));
          // JPEG magic bytes: FF D8
          expect(stripped.bytes[0], equals(0xFF));
          expect(stripped.bytes[1], equals(0xD8));
        },
        failure: (_) => fail('Expected success'),
      );
    });
  });
}
