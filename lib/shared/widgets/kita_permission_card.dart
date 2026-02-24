import 'package:flutter/material.dart';

/// States for the permission request flow.
enum PermissionCardState {
  /// Initial — asking for permission.
  asking,

  /// Permission granted by user.
  granted,

  /// Permission denied by user.
  denied,

  /// Re-asking after denial (max 1 re-ask).
  reAsking,
}

/// Permission request card with contextual storytelling.
///
/// Explains WHY a permission is needed using natural language,
/// not just the system permission dialog.
class KitaPermissionCard extends StatelessWidget {
  const KitaPermissionCard({
    required this.permissionName,
    required this.icon,
    required this.story,
    required this.state,
    this.onAccept,
    this.onDeny,
    super.key,
  });

  /// Human name of the permission (e.g., "Camera").
  final String permissionName;

  /// Context icon for the permission.
  final IconData icon;

  /// Storytelling text explaining why the permission is needed.
  final String story;

  /// Current state of the permission request.
  final PermissionCardState state;

  /// Called when user accepts.
  final VoidCallback? onAccept;

  /// Called when user denies.
  final VoidCallback? onDeny;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Demande de permission : $permissionName. $story',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              icon,
              size: 48,
              color: _iconColor(),
            ),
            const SizedBox(height: 16),
            // Story text
            Text(
              story,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 18,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            _buildActions(),
            // Status text
            if (state == PermissionCardState.granted ||
                state == PermissionCardState.denied)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  state == PermissionCardState.granted
                      ? 'Merci !'
                      : 'Permission refusee',
                  style: TextStyle(
                    color: state == PermissionCardState.granted
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _iconColor() => switch (state) {
        PermissionCardState.granted => const Color(0xFF10B981),
        PermissionCardState.denied => const Color(0xFFEF4444),
        _ => const Color(0xFF0D9488),
      };

  Widget _buildActions() {
    final showButtons = state == PermissionCardState.asking ||
        state == PermissionCardState.reAsking;

    if (!showButtons) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Deny button
        Semantics(
          button: true,
          label: 'Refuser',
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onDeny,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE2E8F0),
                side: const BorderSide(color: Color(0xFF64748B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text('Refuser'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Accept button (56px height for critical action)
        Semantics(
          button: true,
          label: 'Accepter',
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: const Text(
                'Accepter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
