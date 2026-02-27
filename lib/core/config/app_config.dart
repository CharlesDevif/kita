/// Application-wide configuration constants.
///
/// Timeouts, TTL values, and version info.
/// Resource quotas and thresholds are in [Limits].
abstract final class AppConfig {
  // AI Provider timeouts
  static const Duration aiCloudTimeout = Duration(seconds: 3);
  static const Duration aiLocalTimeout = Duration(seconds: 15);
  static const Duration pluginTimeout = Duration(seconds: 10);
  static const Duration networkTimeout = Duration(seconds: 10);

  // Cache TTL by request priority
  static const Duration cacheTtlCritical = Duration.zero; // never cached
  static const Duration cacheTtlUrgent = Duration(seconds: 30);
  static const Duration cacheTtlStandard = Duration(minutes: 5);
  static const Duration cacheTtlBackground = Duration(hours: 1);

  // Episode cleanup
  static const Duration episodeRetention = Duration(days: 30);

  // App identity
  static const String appVersion = '0.1.0';
  static const int minAndroidSdk = 31;
  static const String minIosVersion = '16.0';
}
