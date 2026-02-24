import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/di/service_locator.dart';

void main() {
  group('ServiceLocator', () {
    test('init() executes without error', () async {
      await expectLater(ServiceLocator.init(), completes);
    });

    test('init() is idempotent (can be called multiple times)', () async {
      await ServiceLocator.init();
      await expectLater(ServiceLocator.init(), completes);
    });
  });
}
