import 'package:flutter/material.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../../../core/utils/logger.dart';

final _log = KitaLogger('Onboarding');

/// Provider mode for AI access.
enum ProviderMode {
  /// Free discovery mode with limited credits.
  discovery,

  /// Bring Your Own Key mode.
  byok,
}

/// Callback to validate an API key.
typedef ValidateKeyCallback = Future<bool> Function(
  String provider,
  String key,
);

/// Callback to store an API key securely.
typedef StoreKeyCallback = Future<void> Function(
  String provider,
  String key,
);

/// Step for choosing AI provider mode and optionally entering API keys.
///
/// Discovery mode (free, limited credits) is the default.
/// BYOK mode allows entering Anthropic/OpenAI API keys.
class ApiKeySetupStep extends StatefulWidget {
  const ApiKeySetupStep({
    required this.onComplete,
    this.onValidateKey,
    this.onStoreKey,
    super.key,
  });

  /// Called when setup is complete with the chosen mode.
  final void Function(ProviderMode mode) onComplete;

  /// Optional callback to validate an API key.
  final ValidateKeyCallback? onValidateKey;

  /// Optional callback to store an API key securely.
  final StoreKeyCallback? onStoreKey;

  @override
  State<ApiKeySetupStep> createState() => _ApiKeySetupStepState();
}

class _ApiKeySetupStepState extends State<ApiKeySetupStep> {
  ProviderMode? _selectedMode;
  final _keyController = TextEditingController();
  String? _keyError;
  bool _isValidating = false;
  bool _keyStored = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedMode == ProviderMode.byok) {
      return _buildByokScreen(theme);
    }

    return _buildModeSelection(theme);
  }

  Widget _buildModeSelection(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Configuration IA',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          child: Text(
            'Comment veux-tu utiliser Kita ?',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        // Discovery mode (default)
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: 'Mode découverte gratuit avec crédits limités',
            child: FilledButton(
              key: const Key('mode_discovery'),
              onPressed: () {
                _log.info('Selected discovery mode');
                widget.onComplete(ProviderMode.discovery);
              },
              child: const Text('Découverte gratuite'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // BYOK mode
        SizedBox(
          height: KitaAccessibility.touchTargetMin,
          child: Semantics(
            button: true,
            label: 'Entrer mes propres clés API',
            child: OutlinedButton(
              key: const Key('mode_byok'),
              onPressed: () {
                setState(() => _selectedMode = ProviderMode.byok);
              },
              child: const Text('J\'ai mes propres clés'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildByokScreen(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Semantics(
          header: true,
          child: Text(
            'Clé API',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          child: Text(
            'Entre ta clé API Anthropic ou OpenAI.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        // API key input
        Semantics(
          label: 'Clé API. Champ de saisie sécurisé.',
          textField: true,
          child: TextField(
            key: const Key('api_key_input'),
            controller: _keyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Clé API',
              hintText: 'sk-...',
              border: const OutlineInputBorder(),
              errorText: _keyError,
              suffixIcon: _keyStored
                  ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                  : null,
            ),
            onSubmitted: (_) => _validateAndStore(),
          ),
        ),
        const SizedBox(height: 24),
        // Validate button
        SizedBox(
          height: KitaAccessibility.touchTargetCritical,
          child: Semantics(
            button: true,
            label: _keyStored ? 'Continuer' : 'Valider la clé',
            child: FilledButton(
              key: const Key('validate_key'),
              onPressed: _isValidating
                  ? null
                  : _keyStored
                      ? () => widget.onComplete(ProviderMode.byok)
                      : _validateAndStore,
              child: _isValidating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_keyStored ? 'Continuer' : 'Valider'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Back to mode selection
        SizedBox(
          height: KitaAccessibility.touchTargetMin,
          child: Semantics(
            button: true,
            label: 'Retour au choix du mode',
            child: TextButton(
              key: const Key('back_to_modes'),
              onPressed: () {
                setState(() {
                  _selectedMode = null;
                  _keyController.clear();
                  _keyError = null;
                  _keyStored = false;
                });
              },
              child: const Text('Retour'),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Future<void> _validateAndStore() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyError = 'Veuillez entrer une clé API');
      return;
    }

    setState(() {
      _isValidating = true;
      _keyError = null;
    });

    _log.info('Validating API key');

    try {
      // Detect provider from key prefix
      final provider = key.startsWith('sk-ant-') ? 'anthropic' : 'openai';

      bool isValid;
      if (widget.onValidateKey != null) {
        isValid = await widget.onValidateKey!(provider, key);
      } else {
        // Default: accept any non-empty key
        isValid = true;
      }

      if (!mounted) return;

      if (isValid) {
        // Store the key
        if (widget.onStoreKey != null) {
          await widget.onStoreKey!(provider, key);
        }

        if (!mounted) return;
        _log.info('API key stored successfully');
        setState(() {
          _keyStored = true;
          _isValidating = false;
        });
      } else {
        setState(() {
          _keyError = 'Clé invalide. Vérifie et réessaie.';
          _isValidating = false;
        });
      }
    } catch (e) {
      _log.error('API key validation failed', error: e);
      if (mounted) {
        setState(() {
          _keyError = 'Erreur de validation. Réessaie.';
          _isValidating = false;
        });
      }
    }
  }
}
