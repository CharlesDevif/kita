import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/plugins/built_in/alert/frame_preprocessor.dart';

void main() {
  late FramePreprocessor preprocessor;

  setUp(() {
    preprocessor = const FramePreprocessor(inputSize: 640);
  });

  group('convertYuv420ToRgb', () {
    test('converts a 2x2 YUV420 frame to RGB', () {
      // Create a simple 2x2 I420 frame
      // Y plane: 4 bytes, U plane: 1 byte, V plane: 1 byte
      final yuv = Uint8List.fromList([
        // Y plane (2x2)
        128, 128, 128, 128,
        // U plane (1x1)
        128,
        // V plane (1x1)
        128,
      ]);

      final rgb = preprocessor.convertYuv420ToRgb(yuv, 2, 2);

      expect(rgb.length, 2 * 2 * 3);
      // With Y=128, U=128(->0), V=128(->0), we get R=G=B=128
      for (int i = 0; i < rgb.length; i++) {
        expect(rgb[i], closeTo(128, 1)); // Allow rounding error
      }
    });

    test('produces valid RGB values (0-255)', () {
      // Create a 4x4 frame with various Y, U, V values
      final yuv = Uint8List(4 * 4 + 2 * 2 + 2 * 2);
      for (int i = 0; i < 16; i++) {
        yuv[i] = (i * 16).clamp(0, 255); // Y
      }
      for (int i = 16; i < 20; i++) {
        yuv[i] = 200; // U
      }
      for (int i = 20; i < 24; i++) {
        yuv[i] = 50; // V
      }

      final rgb = preprocessor.convertYuv420ToRgb(yuv, 4, 4);

      for (int i = 0; i < rgb.length; i++) {
        expect(rgb[i], greaterThanOrEqualTo(0));
        expect(rgb[i], lessThanOrEqualTo(255));
      }
    });
  });

  group('convertBgra8888ToRgb', () {
    test('swaps blue and red channels', () {
      // BGRA: Blue=10, Green=20, Red=30, Alpha=255
      final bgra = Uint8List.fromList([10, 20, 30, 255]);
      final rgb = preprocessor.convertBgra8888ToRgb(bgra, 1, 1);

      expect(rgb.length, 3);
      expect(rgb[0], 30); // R
      expect(rgb[1], 20); // G
      expect(rgb[2], 10); // B
    });

    test('converts 2x2 BGRA frame', () {
      final bgra = Uint8List.fromList([
        10, 20, 30, 255, // pixel 0
        40, 50, 60, 255, // pixel 1
        70, 80, 90, 255, // pixel 2
        100, 110, 120, 255, // pixel 3
      ]);
      final rgb = preprocessor.convertBgra8888ToRgb(bgra, 2, 2);

      expect(rgb.length, 12);
      // Pixel 0: R=30, G=20, B=10
      expect(rgb[0], 30);
      expect(rgb[1], 20);
      expect(rgb[2], 10);
    });
  });

  group('resizeRgb', () {
    test('returns same bytes when size matches', () {
      final rgb = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      // 1x3 image (3 pixels)
      final result = preprocessor.resizeRgb(rgb, 3, 1, 3, 1);
      expect(result, rgb);
    });

    test('downscales a 4x4 RGB image to 2x2', () {
      // 4x4 RGB = 48 bytes
      final src = Uint8List(4 * 4 * 3);
      for (int i = 0; i < src.length; i++) {
        src[i] = i % 256;
      }
      final result = preprocessor.resizeRgb(src, 4, 4, 2, 2);
      expect(result.length, 2 * 2 * 3);
    });

    test('upscales a 2x2 RGB image to 4x4', () {
      final src = Uint8List.fromList([
        100, 100, 100, 200, 200, 200, // row 0
        50, 50, 50, 150, 150, 150, // row 1
      ]);
      final result = preprocessor.resizeRgb(src, 2, 2, 4, 4);
      expect(result.length, 4 * 4 * 3);
      // Corner pixel should be from source
      expect(result[0], 100);
      expect(result[1], 100);
      expect(result[2], 100);
    });
  });

  group('normalizeToFloat32', () {
    test('normalizes 0 to 0.0', () {
      final input = Uint8List.fromList([0]);
      final result = preprocessor.normalizeToFloat32(input);
      expect(result[0], 0.0);
    });

    test('normalizes 255 to 1.0', () {
      final input = Uint8List.fromList([255]);
      final result = preprocessor.normalizeToFloat32(input);
      expect(result[0], closeTo(1.0, 0.001));
    });

    test('normalizes 128 to ~0.5', () {
      final input = Uint8List.fromList([128]);
      final result = preprocessor.normalizeToFloat32(input);
      expect(result[0], closeTo(0.502, 0.01));
    });

    test('output length matches input', () {
      final input = Uint8List(100);
      final result = preprocessor.normalizeToFloat32(input);
      expect(result.length, 100);
    });

    test('all values in [0.0, 1.0] range', () {
      final input = Uint8List(256);
      for (int i = 0; i < 256; i++) {
        input[i] = i;
      }
      final result = preprocessor.normalizeToFloat32(input);
      for (final v in result) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('preprocessFrame', () {
    test('produces correct output shape for 640x640 input', () {
      // Create a fake 640x640 BGRA frame
      final bgra = Uint8List(640 * 640 * 4);
      final frame = ImageData(
        bytes: bgra,
        mimeType: 'image/bgra8888',
        width: 640,
        height: 640,
      );

      final result = preprocessor.preprocessFrame(
        frame,
        pixelFormat: 'bgra8888',
      );

      expect(result.length, 1 * 640 * 640 * 3);
    });

    test('produces correct output shape for different input size', () {
      // 320x240 BGRA frame
      final bgra = Uint8List(320 * 240 * 4);
      final frame = ImageData(
        bytes: bgra,
        mimeType: 'image/bgra8888',
        width: 320,
        height: 240,
      );

      final result = preprocessor.preprocessFrame(
        frame,
        pixelFormat: 'bgra8888',
      );

      // Still outputs 640x640x3
      expect(result.length, 640 * 640 * 3);
    });

    test('output values are in [0.0, 1.0]', () {
      final bgra = Uint8List(4 * 4 * 4);
      for (int i = 0; i < bgra.length; i++) {
        bgra[i] = 200;
      }
      final small = const FramePreprocessor(inputSize: 4);
      final frame = ImageData(
        bytes: bgra,
        mimeType: 'image/bgra8888',
        width: 4,
        height: 4,
      );

      final result = small.preprocessFrame(frame, pixelFormat: 'bgra8888');

      for (final v in result) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('preprocessFrameInto', () {
    test('fills pre-allocated buffer', () {
      final bgra = Uint8List(4 * 4 * 4);
      for (int i = 0; i < bgra.length; i++) {
        bgra[i] = 128;
      }
      final small = const FramePreprocessor(inputSize: 4);
      final frame = ImageData(
        bytes: bgra,
        mimeType: 'image/bgra8888',
        width: 4,
        height: 4,
      );
      final buffer = Float32List(4 * 4 * 3);

      small.preprocessFrameInto(
        frame,
        pixelFormat: 'bgra8888',
        buffer: buffer,
      );

      for (final v in buffer) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });
}
