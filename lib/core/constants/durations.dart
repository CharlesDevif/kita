/// Duration constants for animations, debounce, polling, and latency targets.
abstract final class KitaDurations {
  // Animation durations (from UX spec)
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration transition = Duration(milliseconds: 300);
  static const Duration stateChange = Duration(milliseconds: 500);

  // Debounce
  static const Duration inputDebounce = Duration(milliseconds: 300);
  static const Duration sttDebounce = Duration(milliseconds: 200);

  // Polling / refresh
  static const Duration batteryCheckInterval = Duration(minutes: 5);
  static const Duration memoryCleanupInterval = Duration(hours: 6);

  // STT/TTS performance targets
  static const Duration sttMaxLatency = Duration(milliseconds: 200);
  static const Duration ttsMaxLatency = Duration(milliseconds: 100);

  // Cold start target
  static const Duration coldStartTarget = Duration(seconds: 3);

  // Alert latency target
  static const Duration alertMaxLatency = Duration(milliseconds: 50);

  // Describe E2E target
  static const Duration describeMaxLatency = Duration(seconds: 5);
}
