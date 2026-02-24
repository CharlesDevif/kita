import 'package:flutter/material.dart';

/// Variant types for KitaFeedbackBubble content.
enum BubbleVariant {
  /// Plain text response.
  text,

  /// Image response (with optional caption).
  image,

  /// Rich content (mixed text + widgets).
  rich,
}

/// Response bubble displayed in the PluginViewport.
///
/// Shows Kita's responses with avatar, content, and timestamp.
/// Supports text, image, and rich content variants.
class KitaFeedbackBubble extends StatelessWidget {
  const KitaFeedbackBubble({
    required this.content,
    required this.timestamp,
    this.variant = BubbleVariant.text,
    super.key,
  });

  /// Text content of the bubble.
  final String content;

  /// When this response was generated.
  final DateTime timestamp;

  /// Visual variant of the bubble.
  final BubbleVariant variant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Reponse de Kita : $content',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kita avatar
            _buildAvatar(),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(),
                  const SizedBox(height: 4),
                  _buildTimestamp(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF8B5CF6)],
        ),
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        content,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');

    return Text(
      '$hour:$minute',
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
      ),
    );
  }
}
