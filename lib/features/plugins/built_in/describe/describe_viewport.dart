import 'package:flutter/material.dart';

import '../../../../shared/widgets/kita_feedback_bubble.dart';
import 'describe_state.dart';

/// Viewport widget for the Describe plugin.
///
/// Displays the captured photo at the top and the description text below.
/// When a detailed description is available, it appears as a second bubble.
/// Shows an offline indicator when in fallback mode.
class DescribeViewport extends StatelessWidget {
  const DescribeViewport({
    required this.state,
    super.key,
  });

  final DescribeState state;

  /// Background color for the viewport.
  static const _backgroundColor = Color(0xFF1A1A2E);

  /// Offline indicator text color (contrast >= 4.5:1 on background).
  static const _offlineTextColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final timestamp = state.describedAt ?? DateTime.now();

    return Container(
      color: _backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo
          if (state.imageData != null) _buildImage(),

          // Offline indicator
          if (state.isOffline) _buildOfflineIndicator(),

          // Description bubble
          if (state.description != null)
            Semantics(
              liveRegion: true,
              child: KitaFeedbackBubble(
                content: state.description!,
                timestamp: timestamp,
                variant: BubbleVariant.image,
              ),
            ),

          // Detailed description bubble
          if (state.detailedDescription != null)
            Semantics(
              liveRegion: true,
              child: KitaFeedbackBubble(
                content: state.detailedDescription!,
                timestamp: timestamp,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return Semantics(
      label: state.description ?? 'Photo en cours de description',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          state.imageData!.bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
          semanticLabel: state.description ?? 'Photo en cours de description',
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: 200,
              color: _backgroundColor,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: _offlineTextColor,
                  size: 48,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Semantics(
      label: 'Mode local, description simplifiee',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              color: _offlineTextColor,
              size: 16,
              semanticLabel: 'Hors ligne',
            ),
            SizedBox(width: 8),
            Text(
              'Mode local',
              style: TextStyle(
                color: _offlineTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
