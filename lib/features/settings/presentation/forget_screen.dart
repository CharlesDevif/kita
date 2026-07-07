import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../memory/di/providers.dart';
import '../../memory/domain/forget_request.dart';
import '../../memory/domain/memory_domain.dart';

final _log = KitaLogger('Settings');

/// Steps of the "right to be forgotten" flow.
enum _ForgetPhase { menu, chooseDomain, confirm, working, done }

/// Real implementation of the right-to-be-forgotten screen.
///
/// Wires the UI to [MemoryVault.forget] + [MemoryVault.auditForget] so a user
/// (Marie, blind, VoiceOver) can erase their data and be told, honestly,
/// whether the erasure was verified. Every destructive action requires an
/// explicit two-step confirmation and every state change is announced.
class ForgetScreen extends ConsumerStatefulWidget {
  const ForgetScreen({super.key});

  @override
  ConsumerState<ForgetScreen> createState() => _ForgetScreenState();
}

class _ForgetScreenState extends ConsumerState<ForgetScreen> {
  _ForgetPhase _phase = _ForgetPhase.menu;

  /// The request awaiting confirmation, and a human phrase describing its target.
  ForgetRequest? _pending;
  String _pendingDescription = '';

  /// Result of the last completed erasure.
  bool _success = false;
  String _resultMessage = '';

  /// Announces [message] assertively for screen-reader users.
  void _announce(String message) {
    if (!mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
        assertiveness: Assertiveness.assertive,
      ),
    );
  }

  /// Moves to the confirmation step for [request] (nothing is erased yet).
  void _select(ForgetRequest request, String description) {
    setState(() {
      _pending = request;
      _pendingDescription = description;
      _phase = _ForgetPhase.confirm;
    });
    _announce(
      "Confirmation requise. Tu es sur le point d'effacer $description. "
      'Cette action est irréversible.',
    );
  }

  /// Aborts a pending confirmation and returns to the menu.
  void _cancel() {
    setState(() {
      _pending = null;
      _pendingDescription = '';
      _phase = _ForgetPhase.menu;
    });
    _announce('Effacement annulé. Aucune donnée supprimée.');
  }

  /// Executes the pending erasure then audits it and reports the outcome.
  Future<void> _confirm() async {
    final request = _pending;
    if (request == null) return;

    setState(() => _phase = _ForgetPhase.working);
    _announce('Effacement en cours.');
    _log.info('Forget requested');

    try {
      final vault = await ref.read(memoryVaultProvider.future);

      final forgetResult = await vault.forget(request);
      if (forgetResult case Failure(:final failure)) {
        _log.warning('Forget operation failed');
        _finish(success: false, message: failure.userMessage);
        return;
      }

      final verified =
          (await vault.auditForget(request)).getOrElse((_) => false);
      if (verified) {
        _log.info('Forget completed and verified');
        _finish(success: true, message: 'Données effacées et vérifiées.');
      } else {
        _log.warning('Forget verification found residual data');
        _finish(
          success: false,
          message:
              'Effacement incomplet. Certaines données subsistent. Réessaie.',
        );
      }
    } catch (e, stack) {
      _log.error('Forget flow crashed', error: e, stackTrace: stack);
      _finish(
        success: false,
        message: 'Une erreur est survenue. Aucune vérification possible.',
      );
    }
  }

  void _finish({required bool success, required String message}) {
    if (!mounted) return;
    setState(() {
      _phase = _ForgetPhase.done;
      _success = success;
      _resultMessage = message;
    });
    _announce(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vaultAsync = ref.watch(memoryVaultProvider);

    return Semantics(
      container: true,
      label: "Écran du droit à l'oubli",
      child: Scaffold(
        appBar: AppBar(title: const Text("Droit à l'oubli")),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: vaultAsync.when(
              loading: () => _buildLoading(theme),
              error: (_, __) => _buildVaultError(theme),
              data: (_) => _buildPhase(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(ThemeData theme) {
    return switch (_phase) {
      _ForgetPhase.menu => _buildMenu(theme),
      _ForgetPhase.chooseDomain => _buildChooseDomain(theme),
      _ForgetPhase.confirm => _buildConfirm(theme),
      _ForgetPhase.working => _buildWorking(theme),
      _ForgetPhase.done => _buildDone(theme),
    };
  }

  // --- Phases ---------------------------------------------------------------

  Widget _buildMenu(ThemeData theme) {
    return ListView(
      children: [
        _header(theme, 'Effacer mes données'),
        const SizedBox(height: 12),
        Text(
          'Tu peux effacer une catégorie précise, ou bien tout ce que Kita '
          'sait de toi. Une confirmation te sera demandée avant chaque '
          'effacement.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _button(
          theme,
          key: const Key('forget_domain'),
          text: 'Effacer une catégorie',
          semanticLabel: 'Effacer une catégorie de mémoire. '
              'Choisir un type de données à effacer.',
          onPressed: () =>
              setState(() => _phase = _ForgetPhase.chooseDomain),
        ),
        _button(
          theme,
          key: const Key('forget_everything'),
          text: 'Tout effacer',
          semanticLabel: 'Tout effacer. Efface définitivement toutes les '
              'données de Kita. Action irréversible.',
          destructive: true,
          onPressed: () => _select(
            ForgetRequest.everything(confirmation: true),
            'toutes tes données',
          ),
        ),
      ],
    );
  }

  Widget _buildChooseDomain(ThemeData theme) {
    return ListView(
      children: [
        _header(theme, 'Quelle catégorie effacer ?'),
        const SizedBox(height: 12),
        Text(
          'Choisis le type de données à effacer. Le reste sera conservé.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _button(
          theme,
          key: const Key('forget_domain_episodic'),
          text: 'Mes souvenirs et événements',
          semanticLabel: 'Effacer mes souvenirs et événements enregistrés.',
          onPressed: () => _select(
            ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
            'tes souvenirs et événements',
          ),
        ),
        _button(
          theme,
          key: const Key('forget_domain_semantic'),
          text: 'Mes préférences',
          semanticLabel: 'Effacer mes préférences enregistrées.',
          onPressed: () => _select(
            ForgetRequest.domain(MemoryDomain.semantic, confirmation: true),
            'tes préférences',
          ),
        ),
        _button(
          theme,
          key: const Key('forget_domain_relational'),
          text: 'Les personnes que je connais',
          semanticLabel: 'Effacer les personnes que Kita connaît.',
          onPressed: () => _select(
            ForgetRequest.domain(MemoryDomain.relational, confirmation: true),
            'les personnes que Kita connaît',
          ),
        ),
        const SizedBox(height: 8),
        _button(
          theme,
          key: const Key('forget_domain_back'),
          text: 'Retour',
          semanticLabel: 'Retour au menu précédent.',
          outlined: true,
          onPressed: () => setState(() => _phase = _ForgetPhase.menu),
        ),
      ],
    );
  }

  Widget _buildConfirm(ThemeData theme) {
    return ListView(
      children: [
        _header(theme, 'Confirmer ?'),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            "Tu es sur le point d'effacer $_pendingDescription. "
            'Cette action est définitive et irréversible.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 32),
        _button(
          theme,
          key: const Key('forget_confirm'),
          text: 'Effacer définitivement',
          semanticLabel:
              'Confirmer et effacer définitivement $_pendingDescription.',
          destructive: true,
          onPressed: _confirm,
        ),
        _button(
          theme,
          key: const Key('forget_cancel'),
          text: 'Annuler',
          semanticLabel: 'Annuler. Ne rien effacer et revenir en arrière.',
          outlined: true,
          onPressed: _cancel,
        ),
      ],
    );
  }

  Widget _buildWorking(ThemeData theme) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Effacement en cours, veuillez patienter.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Effacement en cours…', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    final color =
        _success ? theme.colorScheme.primary : theme.colorScheme.error;
    return ListView(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Icon(
            _success ? Icons.check_circle : Icons.error,
            size: 64,
            color: color,
            semanticLabel: _success ? 'Succès' : 'Échec',
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            _resultMessage,
            key: const Key('forget_result_message'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        _button(
          theme,
          key: const Key('forget_done'),
          text: 'Terminer',
          semanticLabel: 'Terminer et revenir en arrière.',
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              setState(() => _phase = _ForgetPhase.menu);
            }
          },
        ),
      ],
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Chargement de la mémoire en cours.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Chargement…', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultError(ThemeData theme) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Text(
          "Impossible d'accéder à la mémoire pour le moment. "
          'Réessaie plus tard.',
          key: const Key('forget_vault_error'),
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // --- Shared widgets -------------------------------------------------------

  Widget _header(ThemeData theme, String text) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Builds a full-width, screen-reader-friendly action button.
  ///
  /// The visible label and the accessible label are decoupled: the button's
  /// own (redundant) semantics are excluded and replaced by [semanticLabel]
  /// plus the tap action, so VoiceOver reads a single descriptive node.
  Widget _button(
    ThemeData theme, {
    required Key key,
    required String text,
    required String semanticLabel,
    required VoidCallback? onPressed,
    bool destructive = false,
    bool outlined = false,
  }) {
    final height = destructive
        ? KitaAccessibility.touchTargetCritical
        : KitaAccessibility.touchTargetMin;

    final Widget inner = outlined
        ? OutlinedButton(
            key: key,
            onPressed: onPressed,
            child: Text(text),
          )
        : FilledButton(
            key: key,
            onPressed: onPressed,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    textStyle: const TextStyle(
                      fontSize: KitaAccessibility.textSizeBody,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: KitaAccessibility.textSizeBody,
                    ),
                  ),
            child: Text(text),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KitaAccessibility.touchTargetSpacing,
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Semantics(
          button: true,
          label: semanticLabel,
          onTap: onPressed,
          excludeSemantics: true,
          child: inner,
        ),
      ),
    );
  }
}
