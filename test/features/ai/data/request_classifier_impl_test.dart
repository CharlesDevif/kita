import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/data/request_classifier_impl.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

void main() {
  late RequestClassifierImpl classifier;

  setUp(() {
    classifier = RequestClassifierImpl();
  });

  group('RequestClassifierImpl', () {
    group('returns Result.success', () {
      test('always returns a successful Result', () {
        final result = classifier.classify('random text');
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });
    });

    group('critical priority', () {
      const criticalPrompts = [
        'alerte obstacle devant',
        'danger voiture',
        'obstacle detecte',
        'attention marche',
        'stop immediatement',
        'urgence aide',
        'aide moi vite',
        'alert something ahead',
        'warning car approaching',
        'emergency help',
      ];

      for (final prompt in criticalPrompts) {
        test('classifies "$prompt" as critical', () {
          final result = classifier.classify(prompt);
          expect(
            (result as Success<RequestPriority>).value,
            equals(RequestPriority.critical),
          );
        });
      }

      test('is case-insensitive', () {
        final result = classifier.classify('ALERTE DANGER');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.critical),
        );
      });

      test('matches keyword anywhere in prompt', () {
        final result =
            classifier.classify('il y a un obstacle sur le trottoir');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.critical),
        );
      });
    });

    group('urgent priority', () {
      const urgentPrompts = [
        'decris cette scene',
        'décris ce que tu vois',
        'lis ce texte',
        'ou suis-je exactement',
        'où suis-je',
        'qui est la devant moi',
        'qui est là',
        'describe this',
        'read this sign',
      ];

      for (final prompt in urgentPrompts) {
        test('classifies "$prompt" as urgent', () {
          final result = classifier.classify(prompt);
          expect(
            (result as Success<RequestPriority>).value,
            equals(RequestPriority.urgent),
          );
        });
      }
    });

    group('background priority', () {
      const backgroundPrompts = [
        'rappelle moi demain',
        'sauvegarde cette conversation',
        'analyse mes trajets',
        'statistiques de la semaine',
        'historique des trajets',
        'remember this for later',
        'save this note',
        'show stats',
      ];

      for (final prompt in backgroundPrompts) {
        test('classifies "$prompt" as background', () {
          final result = classifier.classify(prompt);
          expect(
            (result as Success<RequestPriority>).value,
            equals(RequestPriority.background),
          );
        });
      }
    });

    group('standard priority (default)', () {
      const standardPrompts = [
        'raconte moi une histoire',
        'explique comment fonctionne le metro',
        'traduis en anglais',
        'bonjour comment ca va',
        'quelle heure est-il',
        'quel temps fait-il',
      ];

      for (final prompt in standardPrompts) {
        test('classifies "$prompt" as standard', () {
          final result = classifier.classify(prompt);
          expect(
            (result as Success<RequestPriority>).value,
            equals(RequestPriority.standard),
          );
        });
      }
    });

    group('edge cases', () {
      test('empty prompt is classified as background', () {
        final result = classifier.classify('');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.background),
        );
      });

      test('whitespace-only prompt is classified as background', () {
        final result = classifier.classify('   ');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.background),
        );
      });

      test('critical takes precedence over urgent', () {
        // "decris" is urgent, "danger" is critical — critical wins
        final result = classifier.classify('decris ce danger');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.critical),
        );
      });

      test('critical takes precedence over background', () {
        final result = classifier.classify('sauvegarde alerte obstacle');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.critical),
        );
      });

      test('urgent takes precedence over background', () {
        // "rappelle" is background, "decris" is urgent — urgent wins
        final result = classifier.classify('rappelle moi de decris ca');
        expect(
          (result as Success<RequestPriority>).value,
          equals(RequestPriority.urgent),
        );
      });
    });

    group('performance', () {
      test('classification takes < 1ms', () {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 1000; i++) {
          classifier.classify('alerte obstacle devant moi sur le trottoir');
        }
        sw.stop();
        final avgMicroseconds = sw.elapsedMicroseconds / 1000;
        // Average per call should be well under 1ms (1000 microseconds)
        expect(avgMicroseconds, lessThan(1000));
      });
    });
  });
}
