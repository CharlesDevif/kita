import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/request_classifier.dart';
import 'package:kita/features/ai/domain/request_priority.dart';

class MockRequestClassifier implements RequestClassifier {
  RequestPriority defaultPriority = RequestPriority.standard;

  @override
  Result<RequestPriority> classify(String prompt) {
    return Result.success(defaultPriority);
  }
}
