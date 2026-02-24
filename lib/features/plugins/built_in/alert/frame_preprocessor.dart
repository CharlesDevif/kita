import 'dart:typed_data';

import '../../../ai/domain/image_data.dart';

/// Preprocesses camera frames into Float32 tensors for YOLOv8 inference.
///
/// Pipeline: raw frame -> RGB -> resize 640x640 -> normalize [0.0, 1.0]
/// Output shape: [1, 640, 640, 3] (batch, height, width, channels).
class FramePreprocessor {
  const FramePreprocessor({this.inputSize = 640});

  final int inputSize;

  /// Preprocess an [ImageData] frame into a Float32 tensor.
  ///
  /// The [pixelFormat] determines the conversion pipeline:
  /// - `yuv420` for Android camera frames
  /// - `bgra8888` for iOS camera frames
  ///
  /// Returns a [Float32List] of shape [1, inputSize, inputSize, 3].
  Float32List preprocessFrame(ImageData frame, {required String pixelFormat}) {
    final width = frame.width ?? inputSize;
    final height = frame.height ?? inputSize;

    // Step 1: Convert to RGB
    final Uint8List rgbBytes;
    switch (pixelFormat) {
      case 'yuv420':
        rgbBytes = convertYuv420ToRgb(frame.bytes, width, height);
      case 'bgra8888':
        rgbBytes = convertBgra8888ToRgb(frame.bytes, width, height);
      default:
        // Assume raw RGB
        rgbBytes = frame.bytes;
    }

    // Step 2: Resize to inputSize x inputSize
    final resized = resizeRgb(rgbBytes, width, height, inputSize, inputSize);

    // Step 3: Normalize to [0.0, 1.0] Float32
    return normalizeToFloat32(resized);
  }

  /// Fill a pre-allocated buffer instead of creating a new one.
  void preprocessFrameInto(
    ImageData frame, {
    required String pixelFormat,
    required Float32List buffer,
  }) {
    final width = frame.width ?? inputSize;
    final height = frame.height ?? inputSize;

    final Uint8List rgbBytes;
    switch (pixelFormat) {
      case 'yuv420':
        rgbBytes = convertYuv420ToRgb(frame.bytes, width, height);
      case 'bgra8888':
        rgbBytes = convertBgra8888ToRgb(frame.bytes, width, height);
      default:
        rgbBytes = frame.bytes;
    }

    final resized = resizeRgb(rgbBytes, width, height, inputSize, inputSize);

    final length = resized.length;
    for (int i = 0; i < length; i++) {
      buffer[i] = resized[i] / 255.0;
    }
  }

  /// Convert YUV420 (I420 planar) to RGB.
  ///
  /// Y plane: width * height bytes
  /// U plane: (width/2) * (height/2) bytes
  /// V plane: (width/2) * (height/2) bytes
  Uint8List convertYuv420ToRgb(Uint8List yuv, int width, int height) {
    final rgb = Uint8List(width * height * 3);
    final int uvStart = width * height;
    final int uvRowStride = width ~/ 2;
    final int uvPlaneSize = uvRowStride * (height ~/ 2);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = uvStart + (y ~/ 2) * uvRowStride + (x ~/ 2);
        final int vIndex = uvIndex + uvPlaneSize;

        final int yVal = yuv[yIndex];
        final int u = yuv[uvIndex] - 128;
        final int v = yuv[vIndex] - 128;

        final int rgbIndex = yIndex * 3;
        rgb[rgbIndex] = (yVal + 1.402 * v).round().clamp(0, 255);
        rgb[rgbIndex + 1] =
            (yVal - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
        rgb[rgbIndex + 2] = (yVal + 1.772 * u).round().clamp(0, 255);
      }
    }
    return rgb;
  }

  /// Convert BGRA8888 to RGB.
  Uint8List convertBgra8888ToRgb(Uint8List bgra, int width, int height) {
    final pixelCount = width * height;
    final rgb = Uint8List(pixelCount * 3);

    for (int i = 0; i < pixelCount; i++) {
      final bgraIndex = i * 4;
      final rgbIndex = i * 3;
      rgb[rgbIndex] = bgra[bgraIndex + 2]; // R
      rgb[rgbIndex + 1] = bgra[bgraIndex + 1]; // G
      rgb[rgbIndex + 2] = bgra[bgraIndex]; // B
    }
    return rgb;
  }

  /// Resize an RGB image using nearest-neighbor interpolation.
  ///
  /// Simple and fast for real-time preprocessing.
  Uint8List resizeRgb(
    Uint8List rgbBytes,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
  ) {
    if (srcWidth == dstWidth && srcHeight == dstHeight) {
      return rgbBytes;
    }

    final result = Uint8List(dstWidth * dstHeight * 3);
    final double xRatio = srcWidth / dstWidth;
    final double yRatio = srcHeight / dstHeight;

    for (int y = 0; y < dstHeight; y++) {
      final int srcY = (y * yRatio).floor().clamp(0, srcHeight - 1);
      for (int x = 0; x < dstWidth; x++) {
        final int srcX = (x * xRatio).floor().clamp(0, srcWidth - 1);
        final int srcIndex = (srcY * srcWidth + srcX) * 3;
        final int dstIndex = (y * dstWidth + x) * 3;
        result[dstIndex] = rgbBytes[srcIndex];
        result[dstIndex + 1] = rgbBytes[srcIndex + 1];
        result[dstIndex + 2] = rgbBytes[srcIndex + 2];
      }
    }
    return result;
  }

  /// Normalize RGB bytes [0, 255] to Float32 [0.0, 1.0].
  Float32List normalizeToFloat32(Uint8List rgbBytes) {
    final float32 = Float32List(rgbBytes.length);
    for (int i = 0; i < rgbBytes.length; i++) {
      float32[i] = rgbBytes[i] / 255.0;
    }
    return float32;
  }
}
