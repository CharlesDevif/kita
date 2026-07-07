import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/logger.dart';
import '../../ai/data/providers/gemma_bridge.dart';
import '../../orchestration/di/providers.dart';
import '../di/diagnostic_providers.dart';

final _log = KitaLogger('Settings');

/// Accessible diagnostic screen: shows the on-device model status and lets
/// the user run a vision inference on a bundled test image, so recognition
/// can be verified without the camera.
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  String? _testResult;
  bool _testing = false;

  Future<void> _runVisionTest() async {
    setState(() => _testing = true);
    _log.info('Diagnostic vision test started');
    try {
      final bytes = (await rootBundle.load('assets/images/test_scene.jpg'))
          .buffer
          .asUint8List();
      final bridge = ref.read(gemmaBridgeProvider);
      final result = await bridge.describeImage(bytes);
      if (!mounted) return;
      setState(() => _testResult = result.description);
      _log.info('Diagnostic vision test succeeded');
      await _announce('Test réussi. ${result.description}');
    } on Object catch (e) {
      _log.warning('Diagnostic vision test failed', error: e);
      if (!mounted) return;
      setState(() => _testResult = 'Le test de reconnaissance a échoué.');
      await _announce('Le test de reconnaissance a échoué.');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Announces [message] to the screen reader for the current view.
  Future<void> _announce(String message) async {
    if (!mounted) return;
    await SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  }

  String _statusLabel(GemmaModelStatus s) => switch (s) {
        GemmaModelStatus.ready => 'Modèle chargé et prêt',
        GemmaModelStatus.loading => 'Modèle en cours de chargement',
        GemmaModelStatus.error => 'Modèle indisponible',
      };

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(gemmaStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'État du modèle de reconnaissance',
              child: statusAsync.when(
                data: (s) => Text(
                  _statusLabel(s),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                loading: () => const Text('Vérification du modèle…'),
                error: (_, __) => const Text('Modèle indisponible'),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Tester la reconnaissance sur une image de test',
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _testing ? null : _runVisionTest,
                  child: Text(
                    _testing ? 'Test en cours…' : 'Tester la reconnaissance',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_testResult != null)
              Semantics(
                label: 'Résultat du test',
                child: Text(_testResult!),
              ),
          ],
        ),
      ),
    );
  }
}
