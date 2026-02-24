import 'dart:ui' show Rect;

/// Urgency classification based on estimated distance.
enum ObstacleUrgency {
  /// Obstacle within 3 meters — immediate danger.
  immediate,

  /// Obstacle between 3 and 10 meters — preventive warning.
  preventive,

  /// Obstacle beyond 10 meters — no action needed.
  none;

  /// Classify urgency from distance in meters.
  static ObstacleUrgency fromDistance(double meters) {
    if (meters < 3.0) return ObstacleUrgency.immediate;
    if (meters <= 10.0) return ObstacleUrgency.preventive;
    return ObstacleUrgency.none;
  }
}

/// A single detected obstacle from the YOLO model.
class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.estimatedDistance,
  });

  /// Construct from raw YOLO output values.
  ///
  /// [cx], [cy], [w], [h] are in pixel coordinates (640x640).
  /// [classId] is the COCO class index.
  /// [score] is the confidence score.
  /// [labelMap] maps class IDs to label strings.
  factory Detection.fromRawOutput({
    required double cx,
    required double cy,
    required double w,
    required double h,
    required int classId,
    required double score,
    required Map<int, String> labelMap,
    double inputSize = 640.0,
  }) {
    final x1 = ((cx - w / 2) / inputSize).clamp(0.0, 1.0);
    final y1 = ((cy - h / 2) / inputSize).clamp(0.0, 1.0);
    final x2 = ((cx + w / 2) / inputSize).clamp(0.0, 1.0);
    final y2 = ((cy + h / 2) / inputSize).clamp(0.0, 1.0);

    final bbox = Rect.fromLTRB(x1, y1, x2, y2);
    final label = labelMap[classId] ?? 'unknown';
    final distance = _estimateDistance(label, bbox);

    return Detection(
      label: label,
      confidence: score,
      boundingBox: bbox,
      estimatedDistance: distance,
    );
  }

  /// COCO class label (e.g. "person", "car").
  final String label;

  /// Confidence score in [0.0, 1.0].
  final double confidence;

  /// Bounding box normalized to [0, 1] range.
  final Rect boundingBox;

  /// Estimated distance in meters (heuristic, nullable).
  final double? estimatedDistance;

  /// Urgency based on estimated distance.
  ObstacleUrgency get urgency =>
      estimatedDistance != null
          ? ObstacleUrgency.fromDistance(estimatedDistance!)
          : ObstacleUrgency.none;

  static double? _estimateDistance(String label, Rect bbox) {
    const realHeights = <String, double>{
      'person': 1.7,
      'car': 1.5,
      'truck': 3.0,
      'bus': 3.0,
      'bicycle': 1.1,
      'motorcycle': 1.1,
      'dog': 0.5,
      'chair': 0.8,
      'fire hydrant': 0.6,
      'stop sign': 0.75,
      'bench': 0.9,
      'traffic light': 0.6,
      'potted plant': 0.5,
      'cat': 0.4,
    };

    final realHeight = realHeights[label];
    if (realHeight == null) return null;

    const focalLengthPx = 500.0;
    final bboxHeightPx = bbox.height * 640.0;
    if (bboxHeightPx <= 0) return null;

    return (realHeight * focalLengthPx) / bboxHeightPx;
  }

  @override
  String toString() =>
      'Detection(label: $label, confidence: ${confidence.toStringAsFixed(2)}, '
      'box: $boundingBox, distance: ${estimatedDistance?.toStringAsFixed(1)}m)';
}
