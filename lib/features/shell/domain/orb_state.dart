/// Visual states of the KitaOrb.
///
/// Each state maps to a distinct animation pattern and color scheme.
enum OrbState {
  /// Default idle state — slow undulation, teal/violet gradient.
  passive,

  /// User speaking or mic active — pulsation effect.
  listening,

  /// AI processing request — accelerated flux animation.
  processing,

  /// AI delivering response — green expansion + glow.
  responding,

  /// Error occurred — red pulse.
  error,

  /// No network / offline mode — grey-teal, slowed animation.
  offline,
}

/// French labels for Semantics / VoiceOver.
extension OrbStateLabel on OrbState {
  String get semanticsLabel => switch (this) {
        OrbState.passive => 'Kita est en veille',
        OrbState.listening => "Kita est a l'ecoute",
        OrbState.processing => 'Kita est en traitement',
        OrbState.responding => 'Kita repond',
        OrbState.error => 'Kita est en erreur',
        OrbState.offline => 'Kita est hors ligne',
      };
}

/// Display sizes for the orb.
enum OrbSize {
  /// Center of screen in passive mode.
  large,

  /// Header position in active mode.
  small,
}
