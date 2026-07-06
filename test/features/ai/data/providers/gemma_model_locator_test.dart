import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/ai/data/providers/gemma_model_locator.dart';

void main() {
  group('GemmaModelLocator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gemma_locator_test');
    });
    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    GemmaModelLocator locatorFor(Directory dir) => GemmaModelLocator(
          externalDirResolver: () async => dir,
          modelFileName: 'model.litertlm',
        );

    test('locate returns null when the model file is absent', () async {
      final locator = locatorFor(tempDir);
      expect(await locator.locate(), isNull);
    });

    test('locate returns the absolute path when the model file exists', () async {
      final modelsDir = Directory('${tempDir.path}/models')..createSync();
      final file = File('${modelsDir.path}/model.litertlm')
        ..writeAsBytesSync([1, 2, 3]);
      final locator = locatorFor(tempDir);
      expect(await locator.locate(), file.path);
    });

    test('expectedPath is under models/ even when absent', () async {
      final locator = locatorFor(tempDir);
      expect(await locator.expectedPath(),
          '${tempDir.path}/models/model.litertlm');
    });

    test('locate returns null when external dir is unavailable', () async {
      final locator = GemmaModelLocator(
        externalDirResolver: () async => null,
        modelFileName: 'model.litertlm',
      );
      expect(await locator.locate(), isNull);
    });
  });
}
