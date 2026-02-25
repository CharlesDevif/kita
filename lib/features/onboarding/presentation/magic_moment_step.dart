import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';

final _log = KitaLogger('Onboarding');

/// Possible states of the magic moment flow.
enum MagicMomentState {
  /// Initial — Kita invites the user to try "décris".
  invitation,

  /// Processing — waiting for the describe pipeline to complete.
  processing,

  /// Success — the description was delivered.
  success,

  /// Failure — something went wrong.
  failure,
}

/// Callback to trigger the real describe pipeline.
///
/// Returns true if the describe flow completed successfully.
typedef DescribeCallback = Future<bool> Function();

/// The "Premier Moment Magique" onboarding step.
///
/// Kita invites the user to try the describe command, then confirms
/// that the system works before completing onboarding.
class MagicMomentStep extends StatefulWidget {
  const MagicMomentStep({
    required this.onComplete,
    this.onDescribe,
    this.onSpeak,
    super.key,
  });

  /// Called when the magic moment is complete (user taps continue).
  final VoidCallback onComplete;

  /// Optional callback to trigger the describe pipeline.
  /// If null, the step simulates success after a delay.
  final DescribeCallback? onDescribe;

  /// Optional callback to speak text via TTS.
  final Future<void> Function(String text)? onSpeak;

  @override
  State<MagicMomentStep> createState() => _MagicMomentStepState();
}

class _MagicMomentStepState extends State<MagicMomentStep> {
  MagicMomentState _state = MagicMomentState.invitation;
  bool _hasSpoken = false;

  @override
  void initState() {
    super.initState();
    _speakInvitation();
  }

  void _speakInvitation() {
    if (_hasSpoken) return;
    _hasSpoken = true;

    if (widget.onSpeak != null) {
      unawaited(widget.onSpeak!(
        'On essaie ? Dis-moi décris et pointe ton téléphone vers quelque chose.',
      ));
    }
  }

  Future<void> _tryDescribe() async {
    setState(() => _state = MagicMomentState.processing);
    _log.info('Magic moment: triggering describe');

    try {
      bool success;
      if (widget.onDescribe != null) {
        success = await widget.onDescribe!();
      } else {
        // Simulate success for testing/fallback
        await Future<void>.delayed(const Duration(milliseconds: 500));
        success = true;
      }

      if (!mounted) return;

      if (success) {
        setState(() => _state = MagicMomentState.success);
        if (widget.onSpeak != null) {
          unawaited(widget.onSpeak!(
            'Je suis prête. Dis-moi ce dont tu as besoin.',
          ));
        }
      } else {
        setState(() => _state = MagicMomentState.failure);
      }
    } catch (e) {
      _log.error('Magic moment failed', error: e);
      if (mounted) {
        setState(() => _state = MagicMomentState.failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        _buildContent(theme),
        const SizedBox(height: 32),
        _buildAction(theme),
        const Spacer(),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return switch (_state) {
      MagicMomentState.invitation => _buildInvitation(theme),
      MagicMomentState.processing => _buildProcessing(theme),
      MagicMomentState.success => _buildSuccess(theme),
      MagicMomentState.failure => _buildFailure(theme),
    };
  }

  Widget _buildInvitation(ThemeData theme) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'Premier essai',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'On essaie ? Dis-moi "décris" et pointe '
            'ton téléphone vers quelque chose.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return Semantics(
      label: 'Description en cours',
      liveRegion: true,
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Je regarde...',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Column(
      children: [
        Semantics(
          child: Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'Je suis prête. Dis-moi ce dont tu as besoin.',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFailure(ThemeData theme) {
    return Column(
      children: [
        Semantics(
          child: Icon(
            Icons.info_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'Pas de souci, on réessayera plus tard. '
            'Continuons la configuration.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildAction(ThemeData theme) {
    return switch (_state) {
      MagicMomentState.invitation => SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Essayer la commande décris',
            child: FilledButton(
              key: const Key('try_describe'),
              onPressed: _tryDescribe,
              child: const Text('Essayer'),
            ),
          ),
        ),
      MagicMomentState.processing => const SizedBox.shrink(),
      MagicMomentState.success || MagicMomentState.failure => SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Continuer',
            child: FilledButton(
              key: const Key('continue_magic'),
              onPressed: widget.onComplete,
              child: const Text('Continuer'),
            ),
          ),
        ),
    };
  }
}
