import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/ai_provider.dart';
import '../domain/ai_request.dart';
import '../domain/ai_response.dart';
import '../domain/ai_router.dart';
import '../domain/request_classifier.dart';
import '../domain/request_priority.dart';
import 'fallback_chain.dart';

/// Implementation of [AIRouter] that classifies requests and routes them
/// through the [FallbackChain].
///
/// The router:
/// 1. Classifies the request priority (if not already set)
/// 2. Delegates to the FallbackChain which handles tier selection and cascading
/// 3. Measures total latency and wraps the response
class AIRouterImpl implements AIRouter {
  AIRouterImpl({
    required RequestClassifier classifier,
    required List<AIProvider> providers,
  })  : _classifier = classifier,
        _providers = List.unmodifiable(providers),
        _fallbackChain = FallbackChain(providers: providers);

  static final _log = KitaLogger('AI');

  final RequestClassifier _classifier;
  final List<AIProvider> _providers;
  final FallbackChain _fallbackChain;

  @override
  List<AIProvider> get availableProviders =>
      _providers.where((p) => p.isAvailable).toList();

  @override
  Future<Result<AIResponse>> route(AIRequest request) async {
    final stopwatch = Stopwatch()..start();

    // Classify the request if it still has default priority.
    final classifiedRequest = _classifyIfNeeded(request);

    _log.debug(
      'Routing request with priority ${classifiedRequest.priority.name}',
    );

    final result = await _fallbackChain.execute(classifiedRequest);
    stopwatch.stop();

    // Wrap the response with accurate total latency.
    return result.map((response) {
      _log.info(
        'Request completed via ${response.meta.providerId} '
        'in ${stopwatch.elapsedMilliseconds}ms '
        '(status: ${response.status.name})',
      );
      return AIResponse(
        content: response.content,
        meta: AIResponseMeta(
          providerId: response.meta.providerId,
          latency: stopwatch.elapsed,
          tier: response.meta.tier,
          cached: response.meta.cached,
        ),
        status: response.status,
      );
    });
  }

  AIRequest _classifyIfNeeded(AIRequest request) {
    // If the request already has a non-default priority, respect it.
    if (request.priority != RequestPriority.standard) {
      return request;
    }

    final result = _classifier.classify(request.prompt);
    final priority = result.getOrElse((_) => RequestPriority.standard);

    if (priority == request.priority) return request;

    return AIRequest(
      prompt: request.prompt,
      imageData: request.imageData,
      priority: priority,
      context: request.context,
      maxTokens: request.maxTokens,
    );
  }
}
