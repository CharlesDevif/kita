import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies that plugin implementations (Describe, Alert) do not import
/// core services directly. Plugins must go through the sandbox interfaces
/// (SensorAccess, AIAccess, MemoryAccess) or the agent framework
/// (KitaAgent, OutputHandle, AgentContext).
///
/// Allowed imports for plugins:
/// - core/errors/ (Result, KitaFailure)
/// - core/utils/logger.dart
/// - ai/domain/ models (AIResponse, ImageData) — domain types only
/// - orchestration/domain/ (KitaAgent, AgentContext, OutputHandle, etc.)
/// - plugins/domain/ (interfaces, models)
/// - shared/widgets/ (shared UI components)
/// - io/domain/ types re-exported by OutputHandle (HapticPattern)
///
/// Forbidden imports for plugins:
/// - io/data/ (ExifStripper, camera implementations, etc.)
/// - ai/data/ (provider implementations)
/// - memory/data/ (Drift DAOs, etc.)
/// - io/presentation/ (direct UI for I/O)
void main() {
  group('Plugin isolation audit', () {
    final pluginDir = Directory('lib/features/plugins/built_in');

    test('Describe plugin does not import io/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/describe'),
        forbiddenPattern: 'io/data/',
        description: 'Describe plugin must not import io/data/ directly',
      );
    });

    test('Describe plugin does not import ai/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/describe'),
        forbiddenPattern: 'ai/data/',
        description: 'Describe plugin must not import ai/data/ directly',
      );
    });

    test('Describe plugin does not import memory/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/describe'),
        forbiddenPattern: 'memory/data/',
        description: 'Describe plugin must not import memory/data/ directly',
      );
    });

    test('Alert plugin does not import io/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/alert'),
        forbiddenPattern: 'io/data/',
        description: 'Alert plugin must not import io/data/ directly',
      );
    });

    test('Alert plugin does not import ai/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/alert'),
        forbiddenPattern: 'ai/data/',
        description: 'Alert plugin must not import ai/data/ directly',
      );
    });

    test('Alert plugin does not import memory/data/', () {
      _verifyNoForbiddenImports(
        Directory('${pluginDir.path}/alert'),
        forbiddenPattern: 'memory/data/',
        description: 'Alert plugin must not import memory/data/ directly',
      );
    });

    test('No plugin imports shell/ directly', () {
      _verifyNoForbiddenImports(
        pluginDir,
        forbiddenPattern: 'shell/',
        description: 'Plugins must not import shell/ directly',
      );
    });

    test('No plugin imports settings/ directly', () {
      _verifyNoForbiddenImports(
        pluginDir,
        forbiddenPattern: 'settings/',
        description: 'Plugins must not import settings/ directly',
      );
    });
  });
}

void _verifyNoForbiddenImports(
  Directory dir, {
  required String forbiddenPattern,
  required String description,
}) {
  if (!dir.existsSync()) {
    fail('Directory ${dir.path} does not exist');
  }

  final violations = <String>[];
  final dartFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('import ') && line.contains(forbiddenPattern)) {
        violations.add('${file.path}:${i + 1}: $line');
      }
    }
  }

  if (violations.isNotEmpty) {
    fail('$description\n\nViolations found:\n${violations.join('\n')}');
  }
}
