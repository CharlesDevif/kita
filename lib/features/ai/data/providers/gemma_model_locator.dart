import 'dart:io';

import 'package:path_provider/path_provider.dart' as pp;

/// Locates the Gemma model file on the device filesystem.
///
/// The model is NOT bundled in the APK. It is pushed once to
/// `getExternalStorageDirectory()/models/<modelFileName>` (via `adb push`)
/// and loaded from there with `flutter_gemma`'s `fromFile`.
class GemmaModelLocator {
  GemmaModelLocator({
    Future<Directory?> Function()? externalDirResolver,
    this.modelFileName = 'gemma-3n-E2B-it-int4.litertlm',
  }) : _externalDirResolver =
            externalDirResolver ?? pp.getExternalStorageDirectory;

  final Future<Directory?> Function() _externalDirResolver;
  final String modelFileName;

  /// Absolute path where the model is expected, even if it is not present yet.
  /// Throws [StateError] if external storage is unavailable.
  Future<String> expectedPath() async {
    final dir = await _externalDirResolver();
    if (dir == null) {
      throw StateError('External storage directory unavailable');
    }
    return '${dir.path}/models/$modelFileName';
  }

  /// Returns the absolute path of the model file if it exists, else `null`.
  Future<String?> locate() async {
    final dir = await _externalDirResolver();
    if (dir == null) return null;
    final path = '${dir.path}/models/$modelFileName';
    return await File(path).exists() ? path : null;
  }
}
