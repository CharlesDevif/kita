import 'image_data.dart';
import 'request_priority.dart';

class AIRequest {
  const AIRequest({
    required this.prompt,
    this.imageData,
    this.priority = RequestPriority.standard,
    this.context = const {},
    this.maxTokens,
  });

  final String prompt;
  final ImageData? imageData;
  final RequestPriority priority;
  final Map<String, dynamic> context;
  final int? maxTokens;
}
