import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/shell_mode.dart';

part 'shell_mode_providers.g.dart';

/// Manages the current shell display mode (passive/active).
@riverpod
class ShellModeNotifier extends _$ShellModeNotifier {
  @override
  ShellMode build() => ShellMode.passive;

  void setMode(ShellMode mode) {
    state = mode;
  }

  void activate() => state = ShellMode.active;
  void deactivate() => state = ShellMode.passive;
}

/// Manages Kita's system status (online/offline/degraded/error).
@riverpod
class KitaStatusNotifier extends _$KitaStatusNotifier {
  @override
  KitaStatus build() => KitaStatus.online;

  void setStatus(KitaStatus status) {
    state = status;
  }
}
