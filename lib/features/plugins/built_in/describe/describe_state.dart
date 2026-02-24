import '../../../ai/domain/image_data.dart';

/// Phases of the describe conversation flow.
enum DescribePhase {
  /// No active description session.
  idle,

  /// Initial description received and displayed.
  describing,

  /// Detailed description received after "plus de details".
  detailed,

  /// Session completed (via "merci" or silence timeout).
  completed,
}

/// State for the describe plugin conversation flow.
///
/// Tracks the current phase, captured image, descriptions,
/// and whether the response was from an offline fallback.
class DescribeState {
  const DescribeState({
    this.phase = DescribePhase.idle,
    this.imageData,
    this.description,
    this.detailedDescription,
    this.isOffline = false,
    this.describedAt,
  });

  final DescribePhase phase;
  final ImageData? imageData;
  final String? description;
  final String? detailedDescription;
  final bool isOffline;

  /// Timestamp when the description was received from AI.
  /// Used by the viewport to display the time without calling DateTime.now()
  /// on every build.
  final DateTime? describedAt;

  /// Returns the last description available (detailed if present, else standard).
  String? get lastDescription => detailedDescription ?? description;

  DescribeState copyWith({
    DescribePhase? phase,
    ImageData? imageData,
    String? description,
    String? detailedDescription,
    bool? isOffline,
    DateTime? describedAt,
  }) {
    return DescribeState(
      phase: phase ?? this.phase,
      imageData: imageData ?? this.imageData,
      description: description ?? this.description,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      isOffline: isOffline ?? this.isOffline,
      describedAt: describedAt ?? this.describedAt,
    );
  }

  /// Transition to describing phase with initial description.
  DescribeState withDescription(
    ImageData image,
    String desc, {
    bool offline = false,
    DateTime? describedAt,
  }) {
    return DescribeState(
      phase: DescribePhase.describing,
      imageData: image,
      description: desc,
      isOffline: offline,
      describedAt: describedAt ?? DateTime.now(),
    );
  }

  /// Transition to detailed phase with enriched description.
  DescribeState withDetailedDescription(
    String detail, {
    bool offline = false,
    DateTime? describedAt,
  }) {
    return copyWith(
      phase: DescribePhase.detailed,
      detailedDescription: detail,
      isOffline: offline,
      describedAt: describedAt ?? DateTime.now(),
    );
  }

  /// Transition to completed phase.
  DescribeState toCompleted() {
    return copyWith(phase: DescribePhase.completed);
  }

  /// Reset to idle (clears all data).
  static const DescribeState idle = DescribeState();
}
