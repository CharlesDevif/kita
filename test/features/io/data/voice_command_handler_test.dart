import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/io/data/voice_command_handler.dart';

void main() {
  group('VoiceCommandHandler', () {
    group('recognize', () {
      test('recognizes "decris" as describe', () {
        final result = VoiceCommandHandler.recognize('decris');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.describe));
      });

      test('recognizes "decrit" as describe (variation)', () {
        final result = VoiceCommandHandler.recognize('decrit');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.describe));
      });

      test('recognizes "lis ca" as read', () {
        final result = VoiceCommandHandler.recognize('lis ca');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.read));
      });

      test('recognizes "lis ça" as read (with accent)', () {
        final result = VoiceCommandHandler.recognize('lis ça');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.read));
      });

      test('recognizes "stop" as stop', () {
        final result = VoiceCommandHandler.recognize('stop');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.stop));
      });

      test('recognizes "arrete" as stop', () {
        final result = VoiceCommandHandler.recognize('arrete');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.stop));
      });

      test('recognizes "aide" as help', () {
        final result = VoiceCommandHandler.recognize('aide');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.help));
      });

      test('recognizes "merci" as thanks', () {
        final result = VoiceCommandHandler.recognize('merci');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.thanks));
      });

      test('recognizes "repete" as repeat', () {
        final result = VoiceCommandHandler.recognize('repete');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.repeat));
      });

      test('recognizes "répète" as repeat (with accents)', () {
        final result = VoiceCommandHandler.recognize('répète');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.repeat));
      });

      test('recognizes "plus de details" as moreDetails', () {
        final result = VoiceCommandHandler.recognize('plus de details');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.moreDetails));
      });

      test('recognizes "détaille" as moreDetails (with accent)', () {
        final result = VoiceCommandHandler.recognize('détaille');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.moreDetails));
      });

      test('recognizes "approfondir" as moreDetails', () {
        final result = VoiceCommandHandler.recognize('approfondir');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.moreDetails));
      });

      group('recognizes STT misrecognitions of "décris"', () {
        test('"d\'écran" -> describe (apostrophe + phonetic)', () {
          final result = VoiceCommandHandler.recognize("d'écran");
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"d\u2019écran" -> describe (curly apostrophe)', () {
          final result = VoiceCommandHandler.recognize('d\u2019écran');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"des cris" -> describe (word boundary variant)', () {
          final result = VoiceCommandHandler.recognize('des cris');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"décrie" -> describe', () {
          final result = VoiceCommandHandler.recognize('décrie');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"décris-moi" -> describe', () {
          final result = VoiceCommandHandler.recognize('décris-moi');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"décri" -> describe (truncated)', () {
          final result = VoiceCommandHandler.recognize('décri');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"décrire" -> describe (infinitive)', () {
          final result = VoiceCommandHandler.recognize('décrire');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"Des cris" with leading capital -> describe', () {
          final result = VoiceCommandHandler.recognize('Des cris');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"des crits" -> describe (plural variant)', () {
          final result = VoiceCommandHandler.recognize('des crits');
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });

        test('"D\'écran ce que tu vois" with trailing words -> describe', () {
          final result =
              VoiceCommandHandler.recognize("D'écran ce que tu vois");
          expect(result.isSuccess, isTrue);
          expect(result.getOrNull(), equals(VoiceCommand.describe));
        });
      });

      test('is case-insensitive', () {
        final result = VoiceCommandHandler.recognize('DECRIS');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.describe));
      });

      test('handles mixed case', () {
        final result = VoiceCommandHandler.recognize('Merci');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.thanks));
      });

      test('trims whitespace', () {
        final result = VoiceCommandHandler.recognize('  stop  ');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.stop));
      });

      test('recognizes command with trailing words', () {
        final result = VoiceCommandHandler.recognize('decris ce que tu vois');
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals(VoiceCommand.describe));
      });

      test('returns failure for unrecognized command', () {
        final result = VoiceCommandHandler.recognize('bonjour');
        expect(result.isFailure, isTrue);
      });

      test('returns failure for empty string', () {
        final result = VoiceCommandHandler.recognize('');
        expect(result.isFailure, isTrue);
      });

      test('returns failure for whitespace only', () {
        final result = VoiceCommandHandler.recognize('   ');
        expect(result.isFailure, isTrue);
      });

      test('all 7 commands are recognizable', () {
        final commands = {
          'decris': VoiceCommand.describe,
          'lis ca': VoiceCommand.read,
          'stop': VoiceCommand.stop,
          'aide': VoiceCommand.help,
          'merci': VoiceCommand.thanks,
          'repete': VoiceCommand.repeat,
          'plus de details': VoiceCommand.moreDetails,
        };

        for (final entry in commands.entries) {
          final result = VoiceCommandHandler.recognize(entry.key);
          expect(result.isSuccess, isTrue,
              reason: '${entry.key} should be recognized');
          expect(result.getOrNull(), equals(entry.value),
              reason: '${entry.key} should map to ${entry.value}');
        }
      });
    });
  });
}
