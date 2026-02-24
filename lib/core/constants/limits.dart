/// Numeric constants for resource quotas, thresholds, and UI constraints.
abstract final class Limits {
  // RAM
  static const int maxRamUsageMb = 200;
  static const int maxPluginMemoryMb = 50;

  // Battery
  static const int maxBatteryPercentPerHour = 5;
  static const int lowBatteryThreshold = 20;

  // Plugin quotas
  static const int maxPluginApiCallsPerMinute = 10;
  static const int maxPluginStorageMb = 20;
  static const int maxActivePlugins = 5;

  // AI
  static const int maxRetryCount = 3;
  static const int maxConcurrentAiRequests = 3;

  // Memory domains
  static const int maxEpisodesInMemory = 1000;
  static const int maxPersons = 500;

  // UI accessibility
  static const double minTouchTarget = 48.0;
  static const double criticalTouchTarget = 56.0;
  static const double minTextContrast = 4.5;
  static const double minUiContrast = 3.0;

  // Text scaling
  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;
}
