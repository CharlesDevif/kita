import '../../../core/errors/result.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_response.dart';

abstract interface class AIRouter {
  Future<Result<AIResponse>> route(AIRequest request);
  List<AIProvider> get availableProviders;
}
