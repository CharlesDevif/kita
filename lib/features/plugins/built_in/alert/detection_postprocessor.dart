import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'coco_labels.dart';
import 'detection.dart';

/// Post-processes raw YOLOv8 output tensor into a list of [Detection]s.
///
/// The raw output shape is [1, 84, 8400]:
/// - 84 = 4 (cx, cy, w, h) + 80 (COCO class scores)
/// - 8400 = total predictions across scales
class DetectionPostprocessor {
  const DetectionPostprocessor({
    this.confidenceThreshold = 0.80,
    this.iouThreshold = 0.45,
    this.labelMap = cocoLabels,
    this.inputSize = 640.0,
  });

  final double confidenceThreshold;
  final double iouThreshold;
  final Map<int, String> labelMap;
  final double inputSize;

  /// Process raw output tensor of shape [1][84][8400] into detections.
  List<Detection> postprocess(List<List<List<double>>> rawOutput) {
    // Transpose from [1, 84, 8400] to [8400, 84]
    final transposed = transpose(rawOutput);
    return _filterAndNms(transposed);
  }

  /// Process from a pre-transposed [8400, 84] list.
  List<Detection> postprocessTransposed(List<List<double>> transposed) {
    return _filterAndNms(transposed);
  }

  /// Transpose raw [1][84][8400] -> [8400][84].
  ///
  /// Uses a pre-allocated [Float64List] buffer to avoid creating ~705K
  /// small [double] objects that would pressure the GC.
  List<List<double>> transpose(List<List<List<double>>> raw) {
    final numPredictions = raw[0][0].length; // 8400
    final numFields = raw[0].length; // 84
    final batch = raw[0];

    // Pre-allocate a flat buffer, then build views
    final flat = Float64List(numPredictions * numFields);
    for (int j = 0; j < numFields; j++) {
      final field = batch[j];
      for (int i = 0; i < numPredictions; i++) {
        flat[i * numFields + j] = field[i];
      }
    }

    return List.generate(
      numPredictions,
      (i) {
        final offset = i * numFields;
        return List<double>.generate(
          numFields,
          (j) => flat[offset + j],
        );
      },
    );
  }

  List<Detection> _filterAndNms(List<List<double>> transposed) {
    final candidates = <Detection>[];

    for (final row in transposed) {
      // Extract bounding box (cx, cy, w, h) — pixel coords
      final cx = row[0];
      final cy = row[1];
      final w = row[2];
      final h = row[3];

      // Find best class score and index among the 80 classes
      double maxScore = 0.0;
      int classId = 0;
      for (int c = 4; c < 84; c++) {
        if (row[c] > maxScore) {
          maxScore = row[c];
          classId = c - 4;
        }
      }

      // Filter by confidence (strictly greater than threshold)
      if (maxScore <= confidenceThreshold) continue;

      candidates.add(Detection.fromRawOutput(
        cx: cx,
        cy: cy,
        w: w,
        h: h,
        classId: classId,
        score: maxScore,
        labelMap: labelMap,
        inputSize: inputSize,
      ));
    }

    // Apply Non-Maximum Suppression
    return nonMaxSuppression(candidates);
  }

  /// Non-Maximum Suppression: removes overlapping detections.
  List<Detection> nonMaxSuppression(List<Detection> detections) {
    if (detections.isEmpty) return detections;

    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];

    for (final det in sorted) {
      bool suppress = false;
      for (final keptDet in kept) {
        if (computeIoU(det.boundingBox, keptDet.boundingBox) > iouThreshold) {
          suppress = true;
          break;
        }
      }
      if (!suppress) kept.add(det);
    }
    return kept;
  }

  /// Compute Intersection over Union of two rectangles.
  static double computeIoU(Rect a, Rect b) {
    final intersection = a.intersect(b);
    final intersectionWidth = intersection.width.clamp(0.0, double.infinity);
    final intersectionHeight = intersection.height.clamp(0.0, double.infinity);
    final intersectionArea = intersectionWidth * intersectionHeight;
    final unionArea =
        a.width * a.height + b.width * b.height - intersectionArea;
    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }
}
