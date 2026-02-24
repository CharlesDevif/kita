/// Priority levels for agent output requests.
///
/// Used by the [OutputCoordinator] to arbitrate when multiple agents
/// want to produce output simultaneously. Lower [level] = higher priority.
///
/// Priority order (highest first): cancel > critical > high > standard > low.
enum OutputPriority implements Comparable<OutputPriority> {
  /// Cancels all current output immediately.
  cancel(0),

  /// Critical alerts (e.g., obstacles < 3m). Interrupts TTS immediately.
  critical(1),

  /// High-priority alerts (e.g., obstacles 3-5m). Waits for phrase end.
  high(2),

  /// Standard output (descriptions, conversation). FIFO queue.
  standard(3),

  /// Low-priority background output. FIFO with 10s timeout.
  low(4);

  const OutputPriority(this.level);

  /// Numeric level where lower = higher priority.
  final int level;

  /// Returns true if this priority is higher than [other].
  bool operator >(OutputPriority other) => level < other.level;

  /// Returns true if this priority is lower than [other].
  bool operator <(OutputPriority other) => level > other.level;

  /// Returns true if this priority is higher than or equal to [other].
  bool operator >=(OutputPriority other) => level <= other.level;

  /// Returns true if this priority is lower than or equal to [other].
  bool operator <=(OutputPriority other) => level >= other.level;

  @override
  int compareTo(OutputPriority other) => level.compareTo(other.level);
}
