import '../../../core/errors/result.dart';
import 'request_priority.dart';

abstract interface class RequestClassifier {
  Result<RequestPriority> classify(String prompt);
}
