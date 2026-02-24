import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/plugin_registry.dart';
import 'plugin_registry_service.dart';

part 'providers.g.dart';

/// Singleton plugin registry — keepAlive since plugins persist across screens.
@Riverpod(keepAlive: true)
PluginRegistryService pluginRegistryService(Ref ref) {
  return PluginRegistryImpl();
}
