import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/plugins/built_in/alert/coco_labels.dart';
import 'package:kita/features/plugins/built_in/alert/detection.dart';

void main() {
  group('ObstacleUrgency', () {
    test('fromDistance returns immediate for distance < 3m', () {
      expect(ObstacleUrgency.fromDistance(0.5), ObstacleUrgency.immediate);
      expect(ObstacleUrgency.fromDistance(2.0), ObstacleUrgency.immediate);
      expect(ObstacleUrgency.fromDistance(2.99), ObstacleUrgency.immediate);
    });

    test('fromDistance returns preventive for distance 3-10m', () {
      expect(ObstacleUrgency.fromDistance(3.0), ObstacleUrgency.preventive);
      expect(ObstacleUrgency.fromDistance(5.0), ObstacleUrgency.preventive);
      expect(ObstacleUrgency.fromDistance(10.0), ObstacleUrgency.preventive);
    });

    test('fromDistance returns none for distance > 10m', () {
      expect(ObstacleUrgency.fromDistance(10.01), ObstacleUrgency.none);
      expect(ObstacleUrgency.fromDistance(50.0), ObstacleUrgency.none);
    });

    test('fromDistance handles edge cases', () {
      expect(ObstacleUrgency.fromDistance(0.0), ObstacleUrgency.immediate);
      // Negative distance treated as immediate
      expect(ObstacleUrgency.fromDistance(-1.0), ObstacleUrgency.immediate);
    });
  });

  group('Detection', () {
    test('constructor stores all fields correctly', () {
      const detection = Detection(
        label: 'person',
        confidence: 0.95,
        boundingBox: Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
        estimatedDistance: 2.5,
      );

      expect(detection.label, 'person');
      expect(detection.confidence, 0.95);
      expect(detection.boundingBox, const Rect.fromLTRB(0.1, 0.2, 0.3, 0.4));
      expect(detection.estimatedDistance, 2.5);
    });

    test('urgency returns immediate for close distance', () {
      const detection = Detection(
        label: 'car',
        confidence: 0.9,
        boundingBox: Rect.fromLTRB(0, 0, 0.5, 0.5),
        estimatedDistance: 1.5,
      );
      expect(detection.urgency, ObstacleUrgency.immediate);
    });

    test('urgency returns preventive for medium distance', () {
      const detection = Detection(
        label: 'car',
        confidence: 0.9,
        boundingBox: Rect.fromLTRB(0, 0, 0.5, 0.5),
        estimatedDistance: 5.0,
      );
      expect(detection.urgency, ObstacleUrgency.preventive);
    });

    test('urgency returns none when distance is null', () {
      const detection = Detection(
        label: 'unknown',
        confidence: 0.9,
        boundingBox: Rect.fromLTRB(0, 0, 0.5, 0.5),
      );
      expect(detection.urgency, ObstacleUrgency.none);
    });

    test('toString does not contain PII', () {
      const detection = Detection(
        label: 'person',
        confidence: 0.95,
        boundingBox: Rect.fromLTRB(0.1, 0.2, 0.3, 0.4),
        estimatedDistance: 2.5,
      );
      final str = detection.toString();
      expect(str, contains('person'));
      expect(str, contains('0.95'));
      expect(str, contains('2.5m'));
      // No GPS coordinates, no user data
      expect(str, isNot(contains('user')));
      expect(str, isNot(contains('gps')));
    });

    group('fromRawOutput', () {
      test('converts pixel coordinates to normalized bbox', () {
        final detection = Detection.fromRawOutput(
          cx: 320.0,
          cy: 320.0,
          w: 640.0,
          h: 640.0,
          classId: 0,
          score: 0.95,
          labelMap: cocoLabels,
        );

        // Full image bbox: 0,0 -> 1,1
        expect(detection.boundingBox.left, closeTo(0.0, 0.01));
        expect(detection.boundingBox.top, closeTo(0.0, 0.01));
        expect(detection.boundingBox.right, closeTo(1.0, 0.01));
        expect(detection.boundingBox.bottom, closeTo(1.0, 0.01));
        expect(detection.label, 'person');
        expect(detection.confidence, 0.95);
      });

      test('clamps bbox to [0, 1] range', () {
        final detection = Detection.fromRawOutput(
          cx: 0.0,
          cy: 0.0,
          w: 100.0,
          h: 100.0,
          classId: 2,
          score: 0.88,
          labelMap: cocoLabels,
        );

        expect(detection.boundingBox.left, greaterThanOrEqualTo(0.0));
        expect(detection.boundingBox.top, greaterThanOrEqualTo(0.0));
        expect(detection.label, 'car');
      });

      test('estimates distance for known objects', () {
        // Person taking ~half the image height
        final detection = Detection.fromRawOutput(
          cx: 320.0,
          cy: 320.0,
          w: 100.0,
          h: 320.0,
          classId: 0, // person
          score: 0.9,
          labelMap: cocoLabels,
        );

        expect(detection.estimatedDistance, isNotNull);
        expect(detection.estimatedDistance!, greaterThan(0));
      });

      test('returns null distance for unknown objects', () {
        final detection = Detection.fromRawOutput(
          cx: 320.0,
          cy: 320.0,
          w: 100.0,
          h: 100.0,
          classId: 4, // airplane — not in reference heights
          score: 0.9,
          labelMap: cocoLabels,
        );

        expect(detection.estimatedDistance, isNull);
      });

      test('handles unknown class IDs', () {
        final detection = Detection.fromRawOutput(
          cx: 320.0,
          cy: 320.0,
          w: 100.0,
          h: 100.0,
          classId: 999,
          score: 0.9,
          labelMap: cocoLabels,
        );

        expect(detection.label, 'unknown');
      });
    });
  });
}
