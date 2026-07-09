import 'package:flutter/material.dart';

import '../domain/input_state.dart';

/// Unified voice/text input zone for the KitaShell.
///
/// Combines a text field with a microphone button (56x56px).
/// 4 states: idle, listening, typing, disabled.
/// Text interface is a complete alternative to voice.
class KitaInput extends StatefulWidget {
  const KitaInput({
    this.state = InputState.idle,
    this.transcription = '',
    this.onTextSubmit,
    this.onMicPressed,
    this.onTextChanged,
    super.key,
  });

  final InputState state;

  /// Live STT transcription text (updated externally).
  final String transcription;

  /// Called when user submits text (Enter key).
  final ValueChanged<String>? onTextSubmit;

  /// Called when mic button is pressed (toggle listening).
  final VoidCallback? onMicPressed;

  /// Called when text field content changes.
  final ValueChanged<String>? onTextChanged;

  @override
  State<KitaInput> createState() => _KitaInputState();
}

class _KitaInputState extends State<KitaInput> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  /// True when the field contains text — switches the suffix to a send button.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.state == InputState.listening ? widget.transcription : null,
    );
    _hasText = _textController.text.trim().isNotEmpty;
    _textController.addListener(_onTextControllerChanged);
    _focusNode = FocusNode();
  }

  void _onTextControllerChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void didUpdateWidget(KitaInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update text field with STT transcription when listening
    if (widget.state == InputState.listening &&
        widget.transcription != oldWidget.transcription) {
      _textController.text = widget.transcription;
      _textController.selection = TextSelection.collapsed(
        offset: widget.transcription.length,
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(String text) {
    if (text.trim().isEmpty) return;
    widget.onTextSubmit?.call(text.trim());
    _textController.clear();
    _textController.selection = const TextSelection.collapsed(offset: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.state == InputState.disabled;
    final isListening = widget.state == InputState.listening;

    return Semantics(
      label: 'Parle ou écris à Kita',
      child: Row(
        children: [
          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !isDisabled,
              onSubmitted: _handleSubmit,
              onChanged: widget.onTextChanged,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Parle ou écris à Kita',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
                filled: true,
                fillColor: const Color(0xFF16213E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D9488),
                    width: 2,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: isListening
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _ListeningIndicator(),
                      )
                    // Bouton envoyer dès qu'il y a du texte tapé — l'icône
                    // micro seule laissait croire qu'on ne pouvait pas
                    // envoyer un message écrit (retour de test terrain).
                    : _hasText
                        ? Semantics(
                            label: 'Envoyer le message',
                            button: true,
                            child: IconButton(
                              onPressed: isDisabled
                                  ? null
                                  : () => _handleSubmit(_textController.text),
                              icon: const Icon(
                                Icons.send,
                                color: Color(0xFF0F766E),
                                size: 26,
                              ),
                            ),
                          )
                        : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Mic button (56x56px critical action)
          Semantics(
            label: isListening ? 'Arrêter le micro' : 'Activer le micro',
            button: true,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Material(
                color:
                    isListening ? const Color(0xFF0D9488) : const Color(0xFF16213E),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isDisabled ? null : widget.onMicPressed,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      color: isListening
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFF94A3B8),
                      size: 28,
                      semanticLabel: null, // Handled by parent Semantics
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated dots indicator shown during STT listening.
class _ListeningIndicator extends StatefulWidget {
  const _ListeningIndicator();

  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationStarted) {
      _startAnimation();
      _animationStarted = true;
    }
  }

  void _startAnimation() {
    // Use MediaQuery for consistency with KitaShell and KitaOrb.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Icon(
          Icons.graphic_eq,
          color: Color.lerp(
            const Color(0xFF94A3B8),
            const Color(0xFF0D9488),
            _controller.value,
          ),
          size: 24,
        );
      },
    );
  }
}
