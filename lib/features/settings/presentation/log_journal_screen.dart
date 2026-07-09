import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../core/utils/logger.dart';

/// Journal de bord : les derniers logs de l'app, consultables et copiables.
///
/// Les logs Kita sont garantis sans PII (règle stricte du projet) — le
/// journal est donc sûr à afficher et à partager pour diagnostiquer un
/// problème rencontré sur l'appareil.
class LogJournalScreen extends StatefulWidget {
  const LogJournalScreen({super.key});

  @override
  State<LogJournalScreen> createState() => _LogJournalScreenState();
}

class _LogJournalScreenState extends State<LogJournalScreen> {
  Future<void> _copyAll(BuildContext context) async {
    final lines = KitaLogger.journal
        .map((e) =>
            '${_time(e.timestamp)} ${e.level.name.toUpperCase()} ${e.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal copié dans le presse-papiers')),
    );
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Color _levelColor(LogLevel level) => switch (level) {
        LogLevel.debug => const Color(0xFF94A3B8),
        LogLevel.info => const Color(0xFFE2E8F0),
        LogLevel.warning => const Color(0xFFFBBF24),
        LogLevel.error || LogLevel.critical => const Color(0xFFF87171),
      };

  @override
  Widget build(BuildContext context) {
    final entries = KitaLogger.journal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          Semantics(
            label: 'Copier tout le journal',
            button: true,
            child: IconButton(
              iconSize: 28,
              onPressed: entries.isEmpty ? null : () => _copyAll(context),
              icon: const Icon(Icons.copy),
            ),
          ),
          Semantics(
            label: 'Rafraîchir le journal',
            button: true,
            child: IconButton(
              iconSize: 28,
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Semantics(
                label: 'Journal vide',
                child: const Text('Aucun événement enregistré pour le moment.'),
              ),
            )
          : SelectionArea(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[entries.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_time(e.timestamp)}  ${e.message}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _levelColor(e.level),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
