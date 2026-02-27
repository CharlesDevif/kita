import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/io/domain/speech_event.dart';
import 'package:kita/features/io/domain/tts_service.dart';
import 'package:kita/features/orchestration/data/output_coordinator.dart';
import 'package:kita/features/orchestration/data/output_handle_impl.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/domain/shell_mode.dart';
import 'package:kita/shared/multi_modal/profile_adapter.dart';

// ==========================================================================
// Mocks
// ==========================================================================

class MockTTSService implements TTSService {
  bool stopCalled = false;
  int stopCallCount = 0;
  List<String> spokenTexts = [];
  bool _isSpeaking = false;
  final StreamController<TtsSpeechEvent> _speechController =
      StreamController<TtsSpeechEvent>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsSpeechEvent> get speechEvents => _speechController.stream;

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    spokenTexts.add(text);
    _isSpeaking = true;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalled = true;
    stopCallCount++;
    _isSpeaking = false;
    return const Result.success(null);
  }

  void reset() {
    stopCalled = false;
    stopCallCount = 0;
    spokenTexts.clear();
    _isSpeaking = false;
  }
}

class MockHapticService implements HapticService {
  List<HapticPattern> triggeredPatterns = [];

  @override
  Future<Result<void>> trigger(HapticPattern pattern) async {
    triggeredPatterns.add(pattern);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> info() => trigger(HapticPattern.info);

  @override
  Future<Result<void>> warning() => trigger(HapticPattern.warning);

  @override
  Future<Result<void>> danger() => trigger(HapticPattern.danger);

  @override
  Future<Result<void>> presence() => trigger(HapticPattern.presence);

  void reset() {
    triggeredPatterns.clear();
  }
}

class MockProfileAdapter implements ProfileAdapter {
  List<String> feedbackCalls = [];
  String _profile = 'blind';

  @override
  String get activeProfile => _profile;
  set activeProfile(String value) => _profile = value;

  @override
  void feedback({
    void Function()? visual,
    void Function()? vocal,
    void Function()? haptic,
  }) {
    feedbackCalls.add('feedback');
    // Blind profile: vocal + haptic.
    vocal?.call();
    haptic?.call();
  }

  void reset() {
    feedbackCalls.clear();
  }
}

class MockAgentBus implements AgentBus {
  List<AgentMessage> publishedMessages = [];

  @override
  void publish(AgentMessage message) {
    publishedMessages.add(message);
  }

  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}

  @override
  void unsubscribe(String agentId) {}

  @override
  Stream<AgentMessage> streamFor(String agentId) =>
      const Stream<AgentMessage>.empty();

  void reset() {
    publishedMessages.clear();
  }
}

// ==========================================================================
// Test helpers
// ==========================================================================

/// Creates an OutputCoordinator wired to mocks with orb/shell state tracking.
class TestHarness {
  TestHarness()
      : clock = FakeClock(),
        tts = MockTTSService(),
        haptic = MockHapticService(),
        profileAdapter = MockProfileAdapter(),
        bus = MockAgentBus(),
        orbStates = [],
        shellModes = [] {
    coordinator = OutputCoordinator(
      tts: tts,
      haptic: haptic,
      profileAdapter: profileAdapter,
      clock: clock,
      bus: bus,
      onOrbStateChanged: orbStates.add,
      onShellModeChanged: shellModes.add,
    );
  }

  final FakeClock clock;
  final MockTTSService tts;
  final MockHapticService haptic;
  final MockProfileAdapter profileAdapter;
  final MockAgentBus bus;
  final List<OrbState> orbStates;
  final List<ShellMode> shellModes;
  late final OutputCoordinator coordinator;

  void dispose() {
    coordinator.dispose();
  }
}

// ==========================================================================
// Helpers
// ==========================================================================

/// Flushes multiple rounds of microtasks to allow async continuations
/// to execute. A single `Future.microtask` may not be enough when
/// multiple async continuations are chained (e.g., completer.complete()
/// followed by code after an await).
Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future.microtask(() {});
  }
}

// ==========================================================================
// Tests
// ==========================================================================

void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
  });

  tearDown(() {
    h.dispose();
  });

  // ---------- AC1: CANCEL ----------

  test('AC1: cancelAll stops TTS, clears queue, sends feedback OK', () async {
    // Enqueue 3 STANDARD messages.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Message 1', OutputPriority.standard));
    await Future.microtask(() {});

    // The first message is now "speaking". Enqueue two more that should wait.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Message 2', OutputPriority.standard));
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Message 3', OutputPriority.standard));
    await Future.microtask(() {});

    // Now cancelAll.
    await h.coordinator.cancelAll();
    await Future.microtask(() {});

    expect(h.tts.stopCalled, isTrue);
    // "OK" should be spoken via ProfileAdapter.
    expect(h.tts.spokenTexts, contains('OK'));
    // The bus should have a cancelAll message.
    expect(
      h.bus.publishedMessages.any((m) => m.type == AgentMessageType.cancelAll),
      isTrue,
    );
    // Focused agent should be null.
    expect(h.coordinator.focusedAgentId, isNull);
  });

  // ---------- AC2: CRITICAL ----------

  test('AC2: CRITICAL interrupts current speech immediately', () async {
    // Start STANDARD speech.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'A long description',
      OutputPriority.standard,
      agentType: AgentType.onDemand,
    ));
    await Future.microtask(() {});

    expect(h.tts.spokenTexts, contains('A long description'));
    expect(h.coordinator.isSpeaking, isTrue);

    h.tts.stopCalled = false;

    // Now send CRITICAL.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle ahead!',
      OutputPriority.critical,
      agentType: AgentType.persistent,
    ));
    await Future.microtask(() {});

    // TTS.stop() should have been called.
    expect(h.tts.stopCalled, isTrue);
    // The critical message should be spoken.
    expect(h.tts.spokenTexts, contains('Obstacle ahead!'));
    // interruptRequest should be published on the bus.
    expect(
      h.bus.publishedMessages
          .any((m) => m.type == AgentMessageType.interruptRequest),
      isTrue,
    );
    // Focus should be on the critical agent.
    expect(h.coordinator.focusedAgentId, 'alert_agent');
  });

  // ---------- AC3: HIGH waits for phrase end ----------

  test('AC3: HIGH waits for phrase end up to 2s', () async {
    // Start STANDARD speech.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'Description text',
      OutputPriority.standard,
    ));
    await Future.microtask(() {});

    expect(h.tts.spokenTexts, contains('Description text'));

    // Enqueue HIGH.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Warning nearby',
      OutputPriority.high,
    ));
    await Future.microtask(() {});

    // HIGH should wait. No stop yet and no new speech yet (besides original).
    // Simulate speech completion before 2s by calling onSpeechComplete.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});
    await Future.microtask(() {});

    // Now HIGH should have been spoken.
    expect(h.tts.spokenTexts, contains('Warning nearby'));
    expect(h.coordinator.focusedAgentId, 'alert_agent');
  });

  test('AC3: HIGH does not wait more than 2s', () async {
    // Start STANDARD speech.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'Description text',
      OutputPriority.standard,
    ));
    await Future.microtask(() {});

    h.tts.stopCalled = false;

    // Enqueue HIGH.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Warning nearby',
      OutputPriority.high,
    ));
    await Future.microtask(() {});

    // Advance clock past 2s without completing speech.
    h.clock.advance(const Duration(seconds: 2));
    await Future.microtask(() {});
    await Future.microtask(() {});

    // HIGH should have forced an interruption.
    expect(h.tts.stopCalled, isTrue);
    expect(h.tts.spokenTexts, contains('Warning nearby'));
  });

  // ---------- AC4: STANDARD FIFO ----------

  test('AC4: STANDARD messages process in FIFO order', () async {
    // Enqueue 3 STANDARD messages. The first starts immediately,
    // the others queue.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'First', OutputPriority.standard));
    await Future.microtask(() {});

    // Advance clock slightly for unique timestamps.
    h.clock.advance(const Duration(milliseconds: 100));
    unawaited(h.coordinator.enqueueSpeech(
        'agent_b', 'Second', OutputPriority.standard));
    await Future.microtask(() {});

    h.clock.advance(const Duration(milliseconds: 100));
    unawaited(h.coordinator.enqueueSpeech(
        'agent_c', 'Third', OutputPriority.standard));
    await Future.microtask(() {});

    // First should be speaking now.
    expect(h.tts.spokenTexts.first, 'First');

    // Complete first speech.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});
    await Future.microtask(() {});

    // Second should be speaking now.
    expect(h.tts.spokenTexts.contains('Second'), isTrue);

    // Complete second speech.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});
    await Future.microtask(() {});

    // Third should be speaking now.
    expect(h.tts.spokenTexts.contains('Third'), isTrue);

    // Verify order.
    final speechOrder = h.tts.spokenTexts
        .where((t) => t == 'First' || t == 'Second' || t == 'Third')
        .toList();
    expect(speechOrder, ['First', 'Second', 'Third']);
  });

  // ---------- AC5: LOW timeout ----------

  test('AC5: LOW messages dropped after 10s timeout', () async {
    // Enqueue a LOW message.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_bg', 'Background info', OutputPriority.low));
    await Future.microtask(() {});

    // The LOW message starts processing immediately. Complete it.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Now test: enqueue LOW while something else is speaking.
    // First start a STANDARD message.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Blocking speech', OutputPriority.standard));
    await Future.microtask(() {});

    // Now enqueue LOW.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_bg', 'Late low message', OutputPriority.low));
    await Future.microtask(() {});

    // Advance clock past 10s.
    h.clock.advance(const Duration(seconds: 11));

    // Complete the blocking speech.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});
    await Future.microtask(() {});

    // The LOW message should have been dropped.
    expect(h.tts.spokenTexts, isNot(contains('Late low message')));
  });

  test('AC5: LOW messages survive if processed before 10s', () async {
    // Enqueue LOW when nothing is speaking — it processes immediately.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_bg', 'Quick low message', OutputPriority.low));
    await Future.microtask(() {});

    // It should be spoken right away (within the 10s window).
    expect(h.tts.spokenTexts, contains('Quick low message'));
  });

  // ---------- AC6: Cooldown ----------

  test('AC6: cooldown blocks same label_zone within 15s', () async {
    // First alert succeeds.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Poteau a 2 metres',
      OutputPriority.critical,
      cooldownKey: 'poteau_2m',
      distance: 2.0,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    final spokenBefore = h.tts.spokenTexts.length;

    // Advance 5s (still within cooldown).
    h.clock.advance(const Duration(seconds: 5));

    // Same cooldown key — should be dropped.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Poteau a 2 metres encore',
      OutputPriority.critical,
      cooldownKey: 'poteau_2m',
      distance: 2.0,
    ));
    await Future.microtask(() {});

    // No new speech should have happened.
    expect(h.tts.spokenTexts.length, spokenBefore);
  });

  test('AC6: cooldown resets after 15s', () async {
    // First alert.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Poteau a 2 metres',
      OutputPriority.critical,
      cooldownKey: 'poteau_2m',
      distance: 2.0,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Advance 16s (past cooldown).
    h.clock.advance(const Duration(seconds: 16));

    // Same key should now be accepted.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Poteau a 2 metres again',
      OutputPriority.critical,
      cooldownKey: 'poteau_2m',
      distance: 2.0,
    ));
    await Future.microtask(() {});

    expect(h.tts.spokenTexts, contains('Poteau a 2 metres again'));
  });

  // ---------- AC7: Approaching exception ----------

  test('AC7: approaching exception bypasses cooldown (-30% distance)',
      () async {
    // First alert at 5m.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle at 5m',
      OutputPriority.critical,
      cooldownKey: 'obstacle_zone1',
      distance: 5.0,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Advance 3s (still in cooldown).
    h.clock.advance(const Duration(seconds: 3));

    // Same key but distance 3m (40% reduction from 5m).
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle at 3m approaching!',
      OutputPriority.critical,
      cooldownKey: 'obstacle_zone1',
      distance: 3.0,
    ));
    await Future.microtask(() {});

    // Should be spoken despite cooldown.
    expect(h.tts.spokenTexts, contains('Obstacle at 3m approaching!'));
  });

  // ---------- AC8: Deduplication ----------

  test('AC8: dedup drops same agent + same text within 2s', () async {
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle a 2m',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});

    final spokenBefore = h.tts.spokenTexts.length;

    // Advance 1s (within dedup window).
    h.clock.advance(const Duration(seconds: 1));

    // Same text from same agent — should be dropped.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle a 2m',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});

    expect(h.tts.spokenTexts.length, spokenBefore);
  });

  test('AC8: dedup allows same text after 2s', () async {
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle a 2m',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Advance 3s (past dedup window).
    h.clock.advance(const Duration(seconds: 3));

    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Obstacle a 2m',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});

    // Should have been spoken twice total.
    final count =
        h.tts.spokenTexts.where((t) => t == 'Obstacle a 2m').length;
    expect(count, 2);
  });

  // ---------- AC9: Presence haptic ----------

  test('AC9: presence haptic fires 2s after CRITICAL interrupts onDemand',
      () async {
    // DescribeAgent (onDemand) is speaking.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'Beautiful park with trees',
      OutputPriority.standard,
      agentType: AgentType.onDemand,
    ));
    await Future.microtask(() {});

    // CRITICAL interrupts.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Danger!',
      OutputPriority.critical,
      agentType: AgentType.persistent,
    ));
    await Future.microtask(() {});

    // Complete the critical speech.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    h.haptic.reset();

    // Advance 2s — presence haptic should fire.
    h.clock.advance(const Duration(seconds: 2));
    await Future.microtask(() {});

    expect(h.haptic.triggeredPatterns, contains(HapticPattern.presence));
  });

  test('AC9: presence haptic cancelled if new output starts before 2s',
      () async {
    // DescribeAgent (onDemand) is speaking.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'Beautiful park',
      OutputPriority.standard,
      agentType: AgentType.onDemand,
    ));
    await Future.microtask(() {});

    // CRITICAL interrupts.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Danger!',
      OutputPriority.critical,
      agentType: AgentType.persistent,
    ));
    await Future.microtask(() {});

    // Complete the critical speech.
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    h.haptic.reset();

    // Before 2s, start new output (which should cancel the presence timer).
    h.clock.advance(const Duration(seconds: 1));
    unawaited(h.coordinator.enqueueSpeech(
      'agent_x',
      'New output',
      OutputPriority.standard,
    ));
    await Future.microtask(() {});

    // Advance another 2s.
    h.clock.advance(const Duration(seconds: 2));
    await Future.microtask(() {});

    // Presence should NOT have been triggered.
    expect(h.haptic.triggeredPatterns, isNot(contains(HapticPattern.presence)));
  });

  // ---------- AC10: speechEvents stream ----------

  test('AC10: speechEvents emits started then completed for normal flow',
      () async {
    final events = <SpeechEvent>[];
    h.coordinator.speechEventsFor('agent_a').listen(events.add);

    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Hello', OutputPriority.standard));
    await _flushMicrotasks();

    expect(events, contains(SpeechEvent.started));

    h.coordinator.onSpeechComplete();
    await _flushMicrotasks();

    expect(events, contains(SpeechEvent.completed));
    expect(events, orderedEquals([SpeechEvent.started, SpeechEvent.completed]));
  });

  test('AC10: speechEvents emits interrupted when CRITICAL cuts', () async {
    final eventsA = <SpeechEvent>[];
    final eventsB = <SpeechEvent>[];

    h.coordinator.speechEventsFor('agent_a').listen(eventsA.add);
    h.coordinator.speechEventsFor('agent_b').listen(eventsB.add);

    // Agent A starts speaking.
    unawaited(h.coordinator.enqueueSpeech(
      'agent_a',
      'Agent A speaking',
      OutputPriority.standard,
      agentType: AgentType.onDemand,
    ));
    await _flushMicrotasks();

    expect(eventsA, contains(SpeechEvent.started));

    // Agent B interrupts with CRITICAL.
    unawaited(h.coordinator.enqueueSpeech(
      'agent_b',
      'Critical alert!',
      OutputPriority.critical,
      agentType: AgentType.persistent,
    ));
    await _flushMicrotasks();

    // Agent A should get interrupted.
    expect(eventsA, contains(SpeechEvent.interrupted));
    // Agent B should get started.
    expect(eventsB, contains(SpeechEvent.started));
  });

  // ---------- AC11: focusedAgentId ----------

  test('AC11: focusedAgentId tracks last speaking agent', () async {
    // Agent A speaks.
    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'From A', OutputPriority.standard));
    await Future.microtask(() {});
    expect(h.coordinator.focusedAgentId, 'agent_a');

    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Agent B speaks.
    h.clock.advance(const Duration(seconds: 3));
    unawaited(h.coordinator.enqueueSpeech(
        'agent_b', 'From B', OutputPriority.standard));
    await Future.microtask(() {});
    expect(h.coordinator.focusedAgentId, 'agent_b');
  });

  // ---------- AC12: Shell state ----------

  test('AC12: OrbState transitions processing -> responding -> passive',
      () async {
    h.orbStates.clear();

    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Hello', OutputPriority.standard));
    await Future.microtask(() {});

    // Should have transitioned to responding (processing is set briefly
    // for STANDARD, then responding when speech starts).
    expect(h.orbStates, contains(OrbState.responding));

    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    expect(h.orbStates, contains(OrbState.passive));
  });

  // ---------- AC13: Clock injectable ----------

  test('AC13: all timings use injectable Clock', () async {
    // This test verifies that FakeClock controls the cooldown 15s precisely.
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Alert first',
      OutputPriority.critical,
      cooldownKey: 'key_1',
      distance: 5.0,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // At exactly 14s, cooldown should still be active.
    h.clock.advance(const Duration(seconds: 14));
    final spokenBefore = h.tts.spokenTexts.length;

    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Alert should be blocked',
      OutputPriority.critical,
      cooldownKey: 'key_1',
      distance: 5.0,
    ));
    await Future.microtask(() {});
    expect(h.tts.spokenTexts.length, spokenBefore);

    // At 15s+, cooldown should be expired.
    h.clock.advance(const Duration(seconds: 2));
    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Alert should pass',
      OutputPriority.critical,
      cooldownKey: 'key_1',
      distance: 5.0,
    ));
    await Future.microtask(() {});
    expect(h.tts.spokenTexts, contains('Alert should pass'));
  });

  // ---------- AC14: ProfileAdapter ----------

  test('AC14: ProfileAdapter used for all outputs', () async {
    h.profileAdapter.feedbackCalls.clear();

    unawaited(h.coordinator.enqueueSpeech(
        'agent_a', 'Hello', OutputPriority.standard));
    await Future.microtask(() {});

    // ProfileAdapter.feedback should have been called.
    expect(h.profileAdapter.feedbackCalls, isNotEmpty);
    expect(h.profileAdapter.feedbackCalls, contains('feedback'));
  });

  // ---------- AC15: Additional tests ----------

  test('OutputHandleImpl delegates speak to coordinator', () async {
    final handle = OutputHandleImpl(
      agentId: 'test_agent',
      coordinator: h.coordinator,
      onComplete: (_) {},
      agentType: AgentType.onDemand,
    );

    unawaited(handle.speak('Test speech', priority: OutputPriority.standard));
    await _flushMicrotasks();

    expect(h.tts.spokenTexts, contains('Test speech'));
    expect(h.coordinator.focusedAgentId, 'test_agent');
  });

  test('OutputHandleImpl delegates haptic to coordinator', () async {
    final handle = OutputHandleImpl(
      agentId: 'test_agent',
      coordinator: h.coordinator,
      onComplete: (_) {},
    );

    await handle.haptic(HapticPattern.warning);
    await Future.microtask(() {});

    expect(h.haptic.triggeredPatterns, contains(HapticPattern.warning));
  });

  test('OutputHandleImpl exposes speechEvents stream', () async {
    final handle = OutputHandleImpl(
      agentId: 'stream_agent',
      coordinator: h.coordinator,
      onComplete: (_) {},
    );

    final events = <SpeechEvent>[];
    handle.speechEvents.listen(events.add);

    unawaited(
        handle.speak('Streamed speech', priority: OutputPriority.standard));
    await _flushMicrotasks();

    expect(events, contains(SpeechEvent.started));

    h.coordinator.onSpeechComplete();
    await _flushMicrotasks();

    expect(events, contains(SpeechEvent.completed));
  });

  test('dispose cancels all timers and closes streams', () async {
    // Set up a presence timer.
    unawaited(h.coordinator.enqueueSpeech(
      'describe_agent',
      'Description',
      OutputPriority.standard,
      agentType: AgentType.onDemand,
    ));
    await Future.microtask(() {});

    unawaited(h.coordinator.enqueueSpeech(
      'alert_agent',
      'Critical!',
      OutputPriority.critical,
      agentType: AgentType.persistent,
    ));
    await Future.microtask(() {});

    // Dispose should not throw.
    expect(() => h.coordinator.dispose(), returnsNormally);

    // After dispose, enqueueSpeech should be a no-op.
    await h.coordinator.enqueueSpeech(
        'agent_a', 'After dispose', OutputPriority.standard);
    await Future.microtask(() {});

    // "After dispose" should NOT have been spoken.
    expect(h.tts.spokenTexts, isNot(contains('After dispose')));
  });

  test('dedup allows different agents with same text', () async {
    unawaited(h.coordinator.enqueueSpeech(
      'agent_a',
      'Same text',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});
    h.coordinator.onSpeechComplete();
    await Future.microtask(() {});

    // Different agent, same text, within 2s.
    unawaited(h.coordinator.enqueueSpeech(
      'agent_b',
      'Same text',
      OutputPriority.critical,
    ));
    await Future.microtask(() {});

    // Should be spoken because it is from a different agent.
    final count = h.tts.spokenTexts.where((t) => t == 'Same text').length;
    expect(count, 2);
  });
}
