import '../utils/logger.dart';

/// Application flavors.
enum Environment {
  dev,
  staging,
  prod;

  static Environment fromString(String value) {
    return Environment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Environment.dev,
    );
  }
}

/// Runtime environment configuration, resolved at compile time.
///
/// Set via `--dart-define=ENV=dev|staging|prod`.
class EnvironmentConfig {
  const EnvironmentConfig._();

  static const String _envString =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  static final Environment current = Environment.fromString(_envString);

  static bool get isDev => current == Environment.dev;
  static bool get isStaging => current == Environment.staging;
  static bool get isProd => current == Environment.prod;
  static bool get isDebug => !isProd;

  static LogLevel get logLevel => switch (current) {
        Environment.dev => LogLevel.debug,
        Environment.staging => LogLevel.info,
        // info (et non warning) : les logs sont garantis sans PII et le
        // niveau info est indispensable au diagnostic sur device (journal
        // in-app + logcat) — vérifié sur le terrain : à warning, une panne
        // release est indéboguable.
        Environment.prod => LogLevel.info,
      };
}
