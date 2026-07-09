import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Statut transitoire affiché sous forme de bulle pendant le traitement
/// (« Réflexion… », « Je regarde… »). `null` = rien à afficher.
///
/// Session uniquement, jamais persisté.
class ProgressStatus extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final progressStatusProvider =
    NotifierProvider<ProgressStatus, String?>(ProgressStatus.new);
