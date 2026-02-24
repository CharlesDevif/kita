/// Display modes for the KitaShell layout.
enum ShellMode {
  /// Orb large + centered, viewport minimized.
  passive,

  /// Orb small + header, viewport expanded.
  active,
}

/// Connection/system status for the KitaStatusIndicator.
enum KitaStatus {
  /// Connected and operational.
  online,

  /// No network available.
  offline,

  /// Partial — local fallback active.
  degraded,

  /// System error.
  error,
}

/// French labels for status Semantics.
extension KitaStatusLabel on KitaStatus {
  String get semanticsLabel => switch (this) {
        KitaStatus.online => 'Kita est connectee',
        KitaStatus.offline => 'Kita est hors ligne',
        KitaStatus.degraded => 'Kita fonctionne en mode degrade',
        KitaStatus.error => 'Kita a rencontre une erreur',
      };
}
