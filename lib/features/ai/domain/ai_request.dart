import 'image_data.dart';
import 'request_priority.dart';

class AIRequest {
  const AIRequest({
    required this.prompt,
    this.imageData,
    this.priority,
    this.context = const {},
    this.maxTokens,
  });

  final String prompt;
  final ImageData? imageData;

  /// When null, the [RequestClassifier] determines the priority.
  /// When explicitly set (even to [RequestPriority.standard]), the value is
  /// respected and classification is skipped.
  final RequestPriority? priority;

  /// Metadata for internal routing/classification only.
  /// MUST NOT be forwarded to external AI providers — may contain sensitive data.
  final Map<String, dynamic> context;

  final int? maxTokens;
}
