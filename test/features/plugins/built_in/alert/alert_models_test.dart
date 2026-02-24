import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/plugins/built_in/alert/alert_models.dart';

void main() {
  group('AlertUrgency classification', () {
    test('distance < 3m is immediate', () {
      expect(classifyUrgency(0.0), AlertUrgency.immediate);
      expect(classifyUrgency(1.5), AlertUrgency.immediate);
      expect(classifyUrgency(2.99), AlertUrgency.immediate);
    });

    test('distance 3-10m is preventive', () {
      expect(classifyUrgency(3.0), AlertUrgency.preventive);
      expect(classifyUrgency(5.0), AlertUrgency.preventive);
      expect(classifyUrgency(10.0), AlertUrgency.preventive);
    });

    test('distance > 10m is ignored', () {
      expect(classifyUrgency(10.01), AlertUrgency.ignored);
      expect(classifyUrgency(50.0), AlertUrgency.ignored);
    });

    test('negative distance is immediate', () {
      expect(classifyUrgency(-1.0), AlertUrgency.immediate);
    });

    test('exactly 3m is preventive', () {
      expect(classifyUrgency(3.0), AlertUrgency.preventive);
    });

    test('exactly 10m is preventive', () {
      expect(classifyUrgency(10.0), AlertUrgency.preventive);
    });
  });

  group('buildAlertMessage', () {
    test('immediate includes "Attention !"', () {
      final msg = buildAlertMessage(AlertUrgency.immediate, 'voiture', 2.0);
      expect(msg, 'Attention ! voiture a 2 metres');
    });

    test('preventive omits "Attention !"', () {
      final msg = buildAlertMessage(AlertUrgency.preventive, 'travaux', 8.0);
      expect(msg, 'travaux a 8 metres');
    });

    test('ignored returns empty string', () {
      final msg = buildAlertMessage(AlertUrgency.ignored, 'arbre', 15.0);
      expect(msg, '');
    });

    test('rounds distance to nearest integer', () {
      final msg =
          buildAlertMessage(AlertUrgency.immediate, 'personne', 2.7);
      expect(msg, 'Attention ! personne a 3 metres');
    });

    test('rounds distance 0.4 down', () {
      final msg = buildAlertMessage(AlertUrgency.preventive, 'velo', 5.4);
      expect(msg, 'velo a 5 metres');
    });
  });

  group('buildDetailedDescription', () {
    test('includes type, distance, and confidence percentage', () {
      const detection = ObstacleDetection(
        type: 'voiture',
        distance: 2.5,
        confidence: 0.95,
      );
      final desc = buildDetailedDescription(detection);
      expect(desc, contains('voiture'));
      expect(desc, contains('3 metres')); // 2.5.round() == 3 in Dart (rounds half up)
      expect(desc, contains('95 pour cent'));
    });
  });

  group('ObstacleDetection', () {
    test('fromParams parses valid params', () {
      final detection = ObstacleDetection.fromParams({
        'type': 'voiture',
        'distance': 2.0,
        'confidence': 0.95,
      });
      expect(detection.type, 'voiture');
      expect(detection.distance, 2.0);
      expect(detection.confidence, 0.95);
    });

    test('fromParams handles missing fields with defaults', () {
      final detection = ObstacleDetection.fromParams({});
      expect(detection.type, 'obstacle');
      expect(detection.distance, 0.0);
      expect(detection.confidence, 0.0);
    });

    test('fromParams handles int values for distance', () {
      final detection = ObstacleDetection.fromParams({
        'type': 'bus',
        'distance': 5,
        'confidence': 0.9,
      });
      expect(detection.distance, 5.0);
    });

    test('toString does not contain PII', () {
      const detection = ObstacleDetection(
        type: 'voiture',
        distance: 2.5,
        confidence: 0.95,
      );
      final str = detection.toString();
      expect(str, contains('voiture'));
      expect(str, isNot(contains('user')));
      expect(str, isNot(contains('email')));
    });
  });
}
