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
  });

  final DescribePhase phase;
  final ImageData? imageData;
  final String? description;
  final String? detailedDescription;
  final bool isOffline;

  /// Returns the last description available (detailed if present, else standard).
  String? get lastDescription => detailedDescription ?? description;

  DescribeState copyWith({
    DescribePhase? phase,
    ImageData? imageData,
    String? description,
    String? detailedDescription,
    bool? isOffline,
  }) {
    return DescribeState(
      phase: phase ?? this.phase,
      imageData: imageData ?? this.imageData,
      description: description ?? this.description,
      detailedDescription: detailedDescription ?? this.detailedDescription,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  /// Transition to describing phase with initial description.
  DescribeState withDescription(
    ImageData image,
    String desc, {
    bool offline = false,
  }) {
    return DescribeState(
      phase: DescribePhase.describing,
      imageData: image,
      description: desc,
      isOffline: offline,
    );
  }

  /// Transition to detailed phase with enriched description.
  DescribeState withDetailedDescription(String detail, {bool offline = false}) {
    return copyWith(
      phase: DescribePhase.detailed,
      detailedDescription: detail,
      isOffline: offline,
    );
  }

  /// Transition to completed phase.
  DescribeState toCompleted() {
    return copyWith(phase: DescribePhase.completed);
  }

  /// Reset to idle (clears all data).
  static const DescribeState idle = DescribeState();
}
