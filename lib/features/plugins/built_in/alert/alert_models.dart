/// Parsed obstacle detection passed to KitaAlertPlugin.
class ObstacleDetection {
  const ObstacleDetection({
    required this.type,
    required this.distance,
    required this.confidence,
  });

  /// Parse from [PluginRequest.params].
  factory ObstacleDetection.fromParams(Map<String, dynamic> params) {
    return ObstacleDetection(
      type: params['type'] as String? ?? 'obstacle',
      distance: (params['distance'] as num?)?.toDouble() ?? 0.0,
      confidence: (params['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Obstacle type label (e.g. "voiture", "personne").
  final String type;

  /// Estimated distance in meters.
  final double distance;

  /// Detection confidence [0.0, 1.0].
  final double confidence;

  @override
  String toString() =>
      'ObstacleDetection(type: $type, distance: ${distance.toStringAsFixed(1)}m, '
      'confidence: ${confidence.toStringAsFixed(2)})';
}

/// Urgency classification for obstacle alerts.
enum AlertUrgency {
  /// Obstacle within 3 meters — immediate danger.
  immediate,

  /// Obstacle between 3 and 10 meters — preventive warning.
  preventive,

  /// Obstacle beyond 10 meters or below confidence threshold — no alert.
  ignored,
}

/// Classify urgency based on distance in meters.
AlertUrgency classifyUrgency(double distance) {
  if (distance < 3.0) return AlertUrgency.immediate;
  if (distance <= 10.0) return AlertUrgency.preventive;
  return AlertUrgency.ignored;
}

/// Build alert message for TTS based on urgency.
///
/// - immediate: "Attention ! [type] a [distance] metres"
/// - preventive: "[type] a [distance] metres"
String buildAlertMessage(AlertUrgency urgency, String type, double distance) {
  final roundedDistance = distance.round();
  switch (urgency) {
    case AlertUrgency.immediate:
      return 'Attention ! $type a $roundedDistance metres';
    case AlertUrgency.preventive:
      return '$type a $roundedDistance metres';
    case AlertUrgency.ignored:
      return '';
  }
}

/// Build detailed description for "C'est quoi ?" command.
String buildDetailedDescription(ObstacleDetection detection) {
  final percent = (detection.confidence * 100).round();
  return '${detection.type} detecte a ${detection.distance.round()} metres, '
      'confiance $percent pour cent';
}
