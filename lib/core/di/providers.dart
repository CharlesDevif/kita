import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/logger.dart';

part 'providers.g.dart';

/// Global logger provider — keepAlive since logging is needed app-wide.
@Riverpod(keepAlive: true)
KitaLogger kitaLogger(Ref ref) {
  return KitaLogger('Core');
}
