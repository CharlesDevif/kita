import 'package:flutter/material.dart';

import '../../../core/theme/accessibility_tokens.dart';
import '../domain/profile_detection.dart';

/// Profile option displayed in the selector.
class _ProfileOption {
  const _ProfileOption({
    required this.profile,
    required this.label,
    required this.description,
    required this.icon,
    required this.semanticsLabel,
  });

  final AccessibilityProfile profile;
  final String label;
  final String description;
  final IconData icon;
  final String semanticsLabel;
}

const _profileOptions = [
  _ProfileOption(
    profile: AccessibilityProfile.blind,
    label: 'Aveugle',
    description: 'Vocal + haptique',
    icon: Icons.visibility_off,
    semanticsLabel:
        'Profil aveugle. Navigation vocale et haptique. Appuyez pour sélectionner.',
  ),
  _ProfileOption(
    profile: AccessibilityProfile.lowVision,
    label: 'Malvoyant',
    description: 'Grands textes + vocal',
    icon: Icons.visibility_rounded,
    semanticsLabel:
        'Profil malvoyant. Grands textes et assistance vocale. Appuyez pour sélectionner.',
  ),
  _ProfileOption(
    profile: AccessibilityProfile.general,
    label: 'Général',
    description: 'Toutes les modalités',
    icon: Icons.accessibility_new,
    semanticsLabel:
        'Profil général. Toutes les modalités actives. Appuyez pour sélectionner.',
  ),
];

/// Accessible profile selector for the onboarding flow.
///
/// Displays profile options with pre-selection based on detected
/// accessibility features. Each option has proper Semantics labels
/// and meets touch target requirements (56x56px for critical actions).
class ProfileSelector extends StatelessWidget {
  const ProfileSelector({
    required this.selectedProfile,
    required this.onProfileSelected,
    super.key,
  });

  /// Currently selected profile (from detection or user choice).
  final AccessibilityProfile selectedProfile;

  /// Callback when a profile is selected.
  final ValueChanged<AccessibilityProfile> onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Choisis ton profil',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          child: Text(
            'Tu pourras le changer plus tard dans les paramètres.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_profileOptions.length, (index) {
          final option = _profileOptions[index];
          final isSelected = option.profile == selectedProfile;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProfileOptionTile(
              option: option,
              isSelected: isSelected,
              onTap: () => onProfileSelected(option.profile),
              colorScheme: colorScheme,
              textTheme: theme.textTheme,
            ),
          );
        }),
      ],
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final _ProfileOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.semanticsLabel,
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: KitaAccessibility.touchTargetCritical,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: KitaAccessibility.touchTargetCritical,
                  height: KitaAccessibility.touchTargetCritical,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    option.icon,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Text(
                        option.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
