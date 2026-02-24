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

      test('all 6 commands are recognizable', () {
        final commands = {
          'decris': VoiceCommand.describe,
          'lis ca': VoiceCommand.read,
          'stop': VoiceCommand.stop,
          'aide': VoiceCommand.help,
          'merci': VoiceCommand.thanks,
          'repete': VoiceCommand.repeat,
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
