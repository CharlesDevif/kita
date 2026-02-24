import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/orb_state.dart';

part 'orb_providers.g.dart';

/// Manages the current visual state of the KitaOrb.
///
/// Other features (AI, plugins) update this to reflect system status.
@riverpod
class OrbStateNotifier extends _$OrbStateNotifier {
  @override
  OrbState build() => OrbState.passive;

  void setState(OrbState newState) {
    state = newState;
  }
}

/// Manages the orb display size (large/small).
///
/// Controlled by KitaShell based on active/passive mode.
@riverpod
class OrbSizeNotifier extends _$OrbSizeNotifier {
  @override
  OrbSize build() => OrbSize.large;

  void setSize(OrbSize newSize) {
    state = newSize;
  }
}
