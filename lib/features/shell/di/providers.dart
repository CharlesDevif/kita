import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

// =============================================================================
// Template reference for phase 2+ agents.
// Demonstrates the 3 main Riverpod 3.0 code-gen patterns.
// =============================================================================

/// Pattern 1: Simple read-only provider (autoDispose by default).
@riverpod
String shellGreeting(Ref ref) {
  return 'Kita — Initialisation OK';
}

/// Pattern 2: Notifier (mutable synchronous state).
@riverpod
class ShellState extends _$ShellState {
  @override
  String build() => 'idle';

  void updateState(String newState) {
    state = newState;
  }
}

/// Pattern 3: AsyncNotifier (mutable async state).
@riverpod
class ShellInitializer extends _$ShellInitializer {
  @override
  Future<bool> build() async {
    // Placeholder — will be replaced by real init in E8
    return true;
  }
}
