import '../../../core/errors/result.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_response.dart';
import '../../ai/domain/image_data.dart';

abstract interface class AIAccess {
  Future<Result<AIResponse>> complete(AIRequest request);
  Future<Result<AIResponse>> vision(ImageData image, String prompt);
}
