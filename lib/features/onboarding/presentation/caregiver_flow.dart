import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../domain/profile_detection.dart';
import 'magic_moment_step.dart';
import 'profile_selector.dart';

final _log = KitaLogger('Onboarding');

/// Steps within the caregiver flow.
enum CaregiverStep {
  /// Enter the target user's name.
  name,

  /// Select the target user's accessibility profile.
  profile,

  /// Batch permission request.
  permissions,

  /// Guided test ("Dites DECRIS pour verifier").
  test,

  /// Confirmation screen.
  confirmation,
}

/// Callback to request all permissions at once (batch).
typedef BatchPermissionCallback = Future<void> Function();

/// Caregiver onboarding flow — Sophie configures for Marie.
///
/// Steps: name -> profile -> batch permissions -> test guide -> confirmation.
/// The aidant (caregiver) configures Kita for a third party.
class CaregiverFlow extends StatefulWidget {
  const CaregiverFlow({
    required this.onComplete,
    this.onSpeak,
    this.onBatchPermissions,
    this.onDescribe,
    super.key,
  });

  /// Called when the caregiver flow is complete with the target
  /// user's name and selected profile.
  final void Function(String userName, AccessibilityProfile profile) onComplete;

  /// Optional callback to speak text via TTS.
  final Future<void> Function(String text)? onSpeak;

  /// Optional callback to request all permissions in batch.
  final BatchPermissionCallback? onBatchPermissions;

  /// Optional callback to trigger the describe pipeline for the test.
  final DescribeCallback? onDescribe;

  @override
  State<CaregiverFlow> createState() => _CaregiverFlowState();
}

class _CaregiverFlowState extends State<CaregiverFlow> {
  CaregiverStep _step = CaregiverStep.name;
  final _nameController = TextEditingController();
  AccessibilityProfile _selectedProfile = AccessibilityProfile.general;
  String _targetName = '';
  bool _permissionsRequested = false;
  bool _hasSpokenConfirmation = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (_step) {
      CaregiverStep.name => _buildNameStep(theme),
      CaregiverStep.profile => _buildProfileStep(theme),
      CaregiverStep.permissions => _buildPermissionsStep(theme),
      CaregiverStep.test => _buildTestStep(theme),
      CaregiverStep.confirmation => _buildConfirmationStep(theme),
    };
  }

  Widget _buildNameStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Pour qui configurez-vous Kita ?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          child: Text(
            'Entrez le prénom de la personne qui utilisera Kita.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          label: 'Prénom de l\'utilisateur. Champ de saisie.',
          textField: true,
          child: TextField(
            key: const Key('caregiver_name_input'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              hintText: 'Ex : Marie',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitName(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Continuer',
            child: FilledButton(
              key: const Key('caregiver_name_continue'),
              onPressed: _submitName,
              child: const Text('Continuer'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  void _submitName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    _log.info('Caregiver flow: target name entered');
    setState(() {
      _targetName = name;
      _step = CaregiverStep.profile;
    });
  }

  Widget _buildProfileStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        ProfileSelector(
          selectedProfile: _selectedProfile,
          onProfileSelected: (profile) {
            _log.info('Caregiver flow: profile selected');
            setState(() {
              _selectedProfile = profile;
              _step = CaregiverStep.permissions;
            });
          },
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPermissionsStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Permissions',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          child: Text(
            'Kita a besoin de la caméra, du micro et de la localisation '
            'pour fonctionner.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          child: Text(
            'Autorisez les trois permissions d\'un coup.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        if (_permissionsRequested)
          Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Permissions accordées',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: KitaAccessibility.touchTargetCritical,
                child: Semantics(
                  button: true,
                  label: 'Continuer vers le test',
                  child: FilledButton(
                    key: const Key('caregiver_permissions_continue'),
                    onPressed: () {
                      setState(() => _step = CaregiverStep.test);
                    },
                    child: const Text('Continuer'),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            height: KitaAccessibility.touchTargetCritical,
            child: Semantics(
              button: true,
              label: 'Autoriser toutes les permissions',
              child: FilledButton(
                key: const Key('caregiver_grant_all'),
                onPressed: _requestAllPermissions,
                child: const Text('Autoriser tout'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (!_permissionsRequested)
          Center(
            child: SizedBox(
              height: KitaAccessibility.touchTargetMin,
              child: Semantics(
                button: true,
                label: 'Passer les permissions',
                child: TextButton(
                  key: const Key('caregiver_skip_permissions'),
                  onPressed: () {
                    _log.info('Caregiver flow: permissions skipped');
                    setState(() => _step = CaregiverStep.test);
                  },
                  child: const Text('Passer'),
                ),
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  Future<void> _requestAllPermissions() async {
    _log.info('Caregiver flow: requesting batch permissions');

    if (widget.onBatchPermissions != null) {
      await widget.onBatchPermissions!();
    }

    if (!mounted) return;

    setState(() {
      _permissionsRequested = true;
    });
  }

  Widget _buildTestStep(ThemeData theme) {
    return MagicMomentStep(
      onComplete: () {
        setState(() => _step = CaregiverStep.confirmation);
      },
      onDescribe: widget.onDescribe,
      onSpeak: widget.onSpeak,
    );
  }

  Widget _buildConfirmationStep(ThemeData theme) {
    if (!_hasSpokenConfirmation && widget.onSpeak != null) {
      _hasSpokenConfirmation = true;
      unawaited(widget.onSpeak!(
        'Tout est prêt pour $_targetName !',
      ));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          child: Icon(
            Icons.check_circle,
            size: 80,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Tout est prêt pour $_targetName !',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          child: Text(
            'Au prochain lancement, Kita accueillera '
            '$_targetName par son prénom.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Terminer la configuration',
            child: FilledButton(
              key: const Key('caregiver_finish'),
              onPressed: () {
                _log.info('Caregiver flow: completed');
                widget.onComplete(_targetName, _selectedProfile);
              },
              child: const Text('Terminer'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
