import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/plugins/built_in/alert/coco_labels.dart';
import 'package:kita/features/plugins/built_in/alert/detection.dart';
import 'package:kita/features/plugins/built_in/alert/detection_postprocessor.dart';

void main() {
  late DetectionPostprocessor postprocessor;

  setUp(() {
    postprocessor = const DetectionPostprocessor();
  });

  group('transpose', () {
    test('transposes [1][84][8400] to [8400][84]', () {
      // Create a small test: [1][3][2] -> [2][3]
      const small = DetectionPostprocessor(inputSize: 4.0);
      final raw = [
        [
          [1.0, 4.0], // field 0: values for predictions 0 and 1
          [2.0, 5.0], // field 1
          [3.0, 6.0], // field 2
        ]
      ];

      final result = small.transpose(raw);

      expect(result.length, 2);
      expect(result[0].length, 3);
      expect(result[0], [1.0, 2.0, 3.0]); // prediction 0
      expect(result[1], [4.0, 5.0, 6.0]); // prediction 1
    });
  });

  group('postprocess', () {
    /// Create a raw output tensor [1][84][8400] with one detection at index 0.
    List<List<List<double>>> createRawOutput({
      double cx = 320.0,
      double cy = 320.0,
      double w = 100.0,
      double h = 100.0,
      int classId = 0,
      double score = 0.95,
      int numPredictions = 10,
    }) {
      // [1][84][numPredictions]
      return List.generate(1, (_) {
        return List.generate(84, (fieldIdx) {
          return List.generate(numPredictions, (predIdx) {
            if (predIdx == 0) {
              // First prediction has our detection
              if (fieldIdx == 0) return cx;
              if (fieldIdx == 1) return cy;
              if (fieldIdx == 2) return w;
              if (fieldIdx == 3) return h;
              if (fieldIdx == classId + 4) return score;
              return 0.0;
            }
            return 0.0; // All other predictions are empty
          });
        });
      });
    }

    test('detects single high-confidence object', () {
      final raw = createRawOutput(score: 0.95, classId: 0);
      final detections = postprocessor.postprocess(raw);

      expect(detections.length, 1);
      expect(detections[0].label, 'person');
      expect(detections[0].confidence, 0.95);
    });

    test('filters out low confidence detections', () {
      final raw = createRawOutput(score: 0.5); // Below 0.80 threshold
      final detections = postprocessor.postprocess(raw);

      expect(detections, isEmpty);
    });

    test('filters detections at exactly the threshold', () {
      final raw = createRawOutput(score: 0.80);
      final detections = postprocessor.postprocess(raw);

      // 0.80 == threshold, not strictly greater
      expect(detections, isEmpty);
    });

    test('accepts detections just above threshold', () {
      final raw = createRawOutput(score: 0.81);
      final detections = postprocessor.postprocess(raw);

      expect(detections.length, 1);
    });

    test('maps class ID to COCO label', () {
      final raw = createRawOutput(classId: 2, score: 0.9);
      final detections = postprocessor.postprocess(raw);

      expect(detections.length, 1);
      expect(detections[0].label, 'car');
    });

    test('estimates distance for known objects', () {
      final raw = createRawOutput(
        classId: 0, // person
        score: 0.95,
        h: 200.0, // Roughly 1/3 of image height
      );
      final detections = postprocessor.postprocess(raw);

      expect(detections.length, 1);
      expect(detections[0].estimatedDistance, isNotNull);
      expect(detections[0].estimatedDistance!, greaterThan(0));
    });

    test('returns empty list for empty tensor', () {
      // All zeros
      final raw = List.generate(
        1,
        (_) => List.generate(84, (_) => List.filled(10, 0.0)),
      );
      final detections = postprocessor.postprocess(raw);

      expect(detections, isEmpty);
    });

    test('handles different class IDs correctly', () {
      // Put score on class 7 (truck)
      final raw = createRawOutput(classId: 7, score: 0.92);
      final detections = postprocessor.postprocess(raw);

      expect(detections.length, 1);
      expect(detections[0].label, 'truck');
    });
  });

  group('nonMaxSuppression', () {
    test('keeps non-overlapping detections', () {
      final detections = [
        const Detection(
          label: 'person',
          confidence: 0.95,
          boundingBox: Rect.fromLTRB(0.0, 0.0, 0.2, 0.2),
        ),
        const Detection(
          label: 'car',
          confidence: 0.9,
          boundingBox: Rect.fromLTRB(0.5, 0.5, 0.8, 0.8),
        ),
      ];

      final result = postprocessor.nonMaxSuppression(detections);
      expect(result.length, 2);
    });

    test('suppresses overlapping detection with lower confidence', () {
      final detections = [
        const Detection(
          label: 'person',
          confidence: 0.95,
          boundingBox: Rect.fromLTRB(0.1, 0.1, 0.5, 0.5),
        ),
        const Detection(
          label: 'person',
          confidence: 0.85,
          boundingBox: Rect.fromLTRB(0.12, 0.12, 0.52, 0.52), // High overlap
        ),
      ];

      final result = postprocessor.nonMaxSuppression(detections);
      expect(result.length, 1);
      expect(result[0].confidence, 0.95);
    });

    test('returns empty list for empty input', () {
      final result = postprocessor.nonMaxSuppression([]);
      expect(result, isEmpty);
    });

    test('keeps single detection', () {
      final detections = [
        const Detection(
          label: 'car',
          confidence: 0.9,
          boundingBox: Rect.fromLTRB(0.1, 0.1, 0.5, 0.5),
        ),
      ];

      final result = postprocessor.nonMaxSuppression(detections);
      expect(result.length, 1);
    });
  });

  group('computeIoU', () {
    test('returns 1.0 for identical rectangles', () {
      const rect = Rect.fromLTRB(0.1, 0.1, 0.5, 0.5);
      expect(DetectionPostprocessor.computeIoU(rect, rect), closeTo(1.0, 0.001));
    });

    test('returns 0.0 for non-overlapping rectangles', () {
      const a = Rect.fromLTRB(0.0, 0.0, 0.2, 0.2);
      const b = Rect.fromLTRB(0.5, 0.5, 0.8, 0.8);
      expect(DetectionPostprocessor.computeIoU(a, b), 0.0);
    });

    test('returns correct IoU for partial overlap', () {
      const a = Rect.fromLTRB(0.0, 0.0, 0.5, 0.5);
      const b = Rect.fromLTRB(0.25, 0.25, 0.75, 0.75);
      final iou = DetectionPostprocessor.computeIoU(a, b);
      // Intersection: 0.25x0.25 = 0.0625
      // Union: 0.25 + 0.25 - 0.0625 = 0.4375
      // IoU = 0.0625 / 0.4375 ~= 0.143
      expect(iou, closeTo(0.143, 0.01));
    });

    test('handles zero-area rectangles', () {
      const a = Rect.fromLTRB(0.1, 0.1, 0.1, 0.1); // zero area
      const b = Rect.fromLTRB(0.0, 0.0, 0.5, 0.5);
      expect(DetectionPostprocessor.computeIoU(a, b), 0.0);
    });
  });

  group('custom thresholds', () {
    test('uses custom confidence threshold', () {
      const lenient = DetectionPostprocessor(
        confidenceThreshold: 0.5,
      );

      final raw = List.generate(1, (_) {
        return List.generate(84, (fieldIdx) {
          return List.generate(5, (predIdx) {
            if (predIdx == 0) {
              if (fieldIdx == 0) return 320.0;
              if (fieldIdx == 1) return 320.0;
              if (fieldIdx == 2) return 100.0;
              if (fieldIdx == 3) return 100.0;
              if (fieldIdx == 4) return 0.6; // class 0 score
              return 0.0;
            }
            return 0.0;
          });
        });
      });

      final detections = lenient.postprocess(raw);
      expect(detections.length, 1);
    });
  });

  group('cocoLabels', () {
    test('contains 80 classes', () {
      expect(cocoLabels.length, 80);
    });

    test('obstacleClassIds is a subset of cocoLabels keys', () {
      for (final id in obstacleClassIds) {
        expect(cocoLabels.containsKey(id), isTrue,
            reason: 'Missing COCO label for obstacle class $id');
      }
    });
  });
}
