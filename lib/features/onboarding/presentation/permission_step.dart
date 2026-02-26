import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/widgets/kita_permission_card.dart';
import '../data/permission_storytelling_impl.dart';
import '../domain/permission_storytelling.dart';
import '../domain/profile_detection.dart';

final _log = KitaLogger('Onboarding');

/// Onboarding step that requests permissions with storytelling.
///
/// Shows one permission at a time with contextual explanation.
/// Integrates with [KitaPermissionCard] for the visual display.
class PermissionStep extends StatefulWidget {
  const PermissionStep({
    required this.profile,
    required this.onComplete,
    required this.storytelling,
    this.permissionRequester,
    this.onSpeak,
    super.key,
  });

  /// User's accessibility profile (determines permission order).
  final AccessibilityProfile profile;

  /// Called when all permissions have been processed.
  final void Function(List<PermissionResult> results) onComplete;

  /// The storytelling service to use.
  final PermissionStorytelling storytelling;

  /// Optional permission requester for calling the real OS permission API.
  /// If null, accept records granted without calling the OS (test mode).
  final PermissionRequester? permissionRequester;

  /// Optional callback to speak text via TTS (voice-first).
  /// When provided, permissions are announced vocally and the OS dialog
  /// is auto-requested without waiting for the user to tap "Accept".
  final Future<void> Function(String text)? onSpeak;

  @override
  State<PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<PermissionStep> {
  int _currentIndex = 0;
  late List<KitaPermission> _permissions;
  final List<PermissionResult> _results = [];
  PermissionCardState _cardState = PermissionCardState.asking;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _permissions = permissionOrder(widget.profile);
    // Voice-first: speak first permission and auto-request OS dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakAndAutoRequest();
    });
  }

  /// Speak the current permission explanation via TTS and auto-request
  /// the OS permission dialog. Only active when [widget.onSpeak] is set.
  void _speakAndAutoRequest() {
    if (widget.onSpeak == null) return;
    if (_currentIndex >= _permissions.length) return;
    final text = '$_currentName. $_currentExplanation';
    unawaited(widget.onSpeak!(text));
    _requestCurrentPermission();
  }

  KitaPermission get _currentPermission => _permissions[_currentIndex];

  PermissionStory get _currentStory =>
      permissionStories[_currentPermission]!;

  String get _currentExplanation =>
      _cardState == PermissionCardState.reAsking
          ? _currentStory.secondExplanation
          : _currentStory.firstExplanation;

  IconData get _currentIcon => switch (_currentPermission) {
        KitaPermission.camera => Icons.camera_alt,
        KitaPermission.microphone => Icons.mic,
        KitaPermission.location => Icons.location_on,
      };

  String get _currentName => switch (_currentPermission) {
        KitaPermission.camera => 'Caméra',
        KitaPermission.microphone => 'Micro',
        KitaPermission.location => 'Localisation',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentIndex >= _permissions.length;

    if (isLast) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        // Title
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
        const SizedBox(height: 8),
        // Progress indicator
        Semantics(
          label: 'Permission ${_currentIndex + 1} sur ${_permissions.length}',
          child: Text(
            '${_currentIndex + 1} / ${_permissions.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        // Permission card
        KitaPermissionCard(
          permissionName: _currentName,
          icon: _currentIcon,
          story: _currentExplanation,
          state: _cardState,
          onAccept: _isRequesting ? null : _handleAccept,
          onDeny: _isRequesting ? null : _handleDeny,
        ),
        const SizedBox(height: 24),
        // Skip button (always available)
        if (_cardState == PermissionCardState.asking ||
            _cardState == PermissionCardState.reAsking)
          Center(
            child: SizedBox(
              height: KitaAccessibility.touchTargetMin,
              child: Semantics(
                button: true,
                label: 'Passer cette permission',
                child: TextButton(
                  key: const Key('skip_permission'),
                  onPressed: _isRequesting ? null : _handleSkip,
                  child: const Text('Passer'),
                ),
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  void _handleAccept() {
    _requestCurrentPermission();
  }

  void _handleDeny() {
    if (_cardState == PermissionCardState.asking) {
      // First denial -> re-ask
      setState(() {
        _cardState = PermissionCardState.reAsking;
      });
    } else {
      // Second denial -> skip
      _addResultAndAdvance(PermissionResult(
        permission: _currentPermission,
        status: PermissionRequestStatus.denied,
        attempts: 2,
      ));
    }
  }

  void _handleSkip() {
    final attempts =
        _cardState == PermissionCardState.reAsking ? 2 : 1;
    _addResultAndAdvance(PermissionResult(
      permission: _currentPermission,
      status: PermissionRequestStatus.denied,
      attempts: attempts,
    ));
  }

  Future<void> _requestCurrentPermission() async {
    setState(() => _isRequesting = true);

    final attempts = _cardState == PermissionCardState.reAsking ? 2 : 1;

    if (widget.permissionRequester != null) {
      // Call the real OS permission request
      try {
        final status =
            await widget.permissionRequester!.request(_currentPermission);
        if (!mounted) return;
        _log.info(
          'Permission ${_currentPermission.name} result: ${status.name}',
        );
        _addResultAndAdvance(PermissionResult(
          permission: _currentPermission,
          status: status,
          attempts: attempts,
        ));
      } catch (e) {
        _log.error('Permission request failed', error: e);
        if (!mounted) return;
        // Treat errors as denied so the user can retry or skip
        _addResultAndAdvance(PermissionResult(
          permission: _currentPermission,
          status: PermissionRequestStatus.denied,
          attempts: attempts,
        ));
      }
    } else {
      // No requester provided (test mode) — record as granted.
      _addResultAndAdvance(PermissionResult(
        permission: _currentPermission,
        status: PermissionRequestStatus.granted,
        attempts: attempts,
      ));
    }
  }

  void _addResultAndAdvance(PermissionResult result) {
    _results.add(result);

    if (_currentIndex + 1 >= _permissions.length) {
      widget.onComplete(_results);
    } else {
      setState(() {
        _currentIndex++;
        _cardState = PermissionCardState.asking;
        _isRequesting = false;
      });
      // Voice-first: speak and auto-request next permission after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speakAndAutoRequest();
      });
    }
  }
}
