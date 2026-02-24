import 'dart:typed_data';

class ImageData {
  const ImageData({
    required this.bytes,
    this.mimeType = 'image/jpeg',
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mimeType;
  final int? width;
  final int? height;
}
