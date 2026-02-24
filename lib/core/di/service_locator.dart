import 'package:flutter/widgets.dart';

import '../config/environment.dart';
import '../utils/logger.dart';

/// Imperative service initializer called in main() before runApp().
///
/// Initializes bindings, sets log level, and prepares resources.
/// Does NOT manage Riverpod DI — providers handle that.
class ServiceLocator {
  ServiceLocator._();

  static bool _initialized = false;

  static final _logger = KitaLogger('ServiceLocator');

  /// Initialize core services. Idempotent — safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    _logger.info('Boot started');

    // Set log level from environment (dev=debug, staging=info, prod=warning)
    KitaLogger.setMinLevel(EnvironmentConfig.logLevel);

    _initialized = true;

    _logger.info('Boot complete');
  }
}
