import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/request_classifier.dart';
import '../domain/request_priority.dart';

/// Keyword-based implementation of [RequestClassifier].
///
/// Classifies prompts into 4 priority levels by scanning for known keywords.
/// Classification is synchronous and targets < 1ms execution.
class RequestClassifierImpl implements RequestClassifier {
  RequestClassifierImpl();

  static final _log = KitaLogger('AI');

  // Keywords grouped by priority — checked in order from highest to lowest.
  static const _criticalKeywords = [
    'alerte',
    'danger',
    'obstacle',
    'attention',
    'stop',
    'urgence',
    'aide',
    'alert',
    'warning',
    'emergency',
  ];

  static const _urgentKeywords = [
    'decris',
    'décris',
    'lis',
    'ou suis-je',
    'où suis-je',
    'qui est la',
    'qui est là',
    'describe',
    'read',
  ];

  static const _backgroundKeywords = [
    'rappelle',
    'sauvegarde',
    'analyse',
    'statistiques',
    'historique',
    'remember',
    'save',
    'stats',
  ];

  @override
  Result<RequestPriority> classify(String prompt) {
    final normalized = prompt.toLowerCase().trim();

    if (normalized.isEmpty) {
      _log.debug('Empty prompt classified as background');
      return const Result.success(RequestPriority.background);
    }

    // Check critical first — safety-related keywords take absolute priority.
    for (final keyword in _criticalKeywords) {
      if (normalized.contains(keyword)) {
        _log.debug('Classified as critical (keyword match)');
        return const Result.success(RequestPriority.critical);
      }
    }

    // Check urgent — needs quick response but not safety-critical.
    for (final keyword in _urgentKeywords) {
      if (normalized.contains(keyword)) {
        _log.debug('Classified as urgent (keyword match)');
        return const Result.success(RequestPriority.urgent);
      }
    }

    // Check background — deferrable tasks.
    for (final keyword in _backgroundKeywords) {
      if (normalized.contains(keyword)) {
        _log.debug('Classified as background (keyword match)');
        return const Result.success(RequestPriority.background);
      }
    }

    // Default: standard — cloud-quality response preferred.
    _log.debug('Classified as standard (default)');
    return const Result.success(RequestPriority.standard);
  }
}
