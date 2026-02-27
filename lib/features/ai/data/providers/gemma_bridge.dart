import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../../../../core/utils/logger.dart';

/// Status of the Gemma model on device.
enum GemmaModelStatus {
  /// Model is loaded and ready for inference.
  ready,

  /// Model is being loaded / installed.
  loading,

  /// Model failed to load or is not installed.
  error,
}

/// Result from a Gemma text completion.
class GemmaCompletionResult {
  const GemmaCompletionResult({required this.text});

  final String text;
}

/// Result from a Gemma vision (image description) call.
class GemmaVisionResult {
  const GemmaVisionResult({required this.description});

  final String description;
}

/// Abstraction over Gemma on-device LLM via flutter_gemma.
///
/// Production code uses [GemmaBridgeImpl]. Tests inject a mock.
abstract interface class GemmaBridge {
  /// Check if the model is loaded and ready.
  Future<GemmaModelStatus> checkStatus();

  /// Warm up the model with a dummy inference.
  ///
  /// Call this early (e.g. at app boot) so subsequent real calls are fast.
  /// The first inference loads weights into GPU memory and compiles kernels.
  /// Safe to call multiple times — only runs once.
  Future<void> warmUp();

  /// Run a text completion with an optional system prompt.
  Future<GemmaCompletionResult> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  });

  /// Stream text completion token by token.
  ///
  /// Each yielded string is a single token from the LLM. Consumers can
  /// accumulate tokens and pipe them through a [SentenceBuffer] for
  /// phrase-level TTS, reducing perceived latency from ~8s to ~1.5s.
  Stream<String> completeStream(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  });

  /// Describe an image using Gemma vision (multimodal).
  Future<GemmaVisionResult> describeImage(
    Uint8List bytes, {
    String? prompt,
  });

  /// Stream image description token by token.
  ///
  /// Each yielded string is a single token from the vision model.
  /// Consumers can pipe this through [SentenceBuffer] → TTS for
  /// low-latency spoken descriptions.
  Stream<String> describeImageStream(
    Uint8List bytes, {
    String? prompt,
  });

  /// Release native resources.
  Future<void> dispose();
}

/// Real implementation using flutter_gemma 0.12.x.
///
/// Loads a Gemma3n E2B model from Flutter assets. The model must be
/// pre-installed at `assets/models/` and declared in pubspec.yaml.
///
/// Uses GPU backend with CPU fallback. Creates separate chat sessions
/// for text-only and vision requests.
class GemmaBridgeImpl implements GemmaBridge {
  GemmaBridgeImpl({
    this.modelAssetPath = 'assets/models/gemma-3n-E2B-it-int4.litertlm',
  });

  static final _log = KitaLogger('AI.Gemma');

  final String modelAssetPath;

  /// Guard against concurrent inference calls.
  bool _processing = false;

  bool _disposed = false;
  bool _initialized = false;
  bool _warmedUp = false;
  GemmaModelStatus _status = GemmaModelStatus.loading;

  InferenceModel? _textModel;
  InferenceModel? _visionModel;

  /// Persistent text chat session — reuses KV cache between calls,
  /// saving ~2s per subsequent inference.
  InferenceChat? _textChat;

  @override
  Future<GemmaModelStatus> checkStatus() async {
    if (_disposed) return GemmaModelStatus.error;
    if (_initialized) return _status;

    try {
      await _ensureInitialized();
      return _status;
    } on Exception catch (e) {
      _log.warning('Gemma status check failed', error: e);
      _status = GemmaModelStatus.error;
      return GemmaModelStatus.error;
    }
  }

  @override
  Future<void> warmUp() async {
    if (_warmedUp || _disposed) return;

    try {
      await _ensureInitialized();

      _processing = true;
      final chat = await _textModel!.createChat(
        temperature: 0.1,
        topK: 1,
      );

      // Short dummy inference to warm GPU pipeline + compile kernels.
      await chat.addQueryChunk(Message.text(
        text: 'Dis bonjour.',
        isUser: true,
      ));
      await chat.generateChatResponse();

      _warmedUp = true;
      _log.info('Gemma warmup complete');
    } on Exception catch (e) {
      _log.warning('Gemma warmup failed (non-fatal)', error: e);
    } finally {
      _processing = false;
    }
  }

  @override
  Future<GemmaCompletionResult> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    // Delegate to streaming and join all tokens.
    final tokens = <String>[];
    await for (final token in completeStream(
      prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    )) {
      tokens.add(token);
    }
    final text = tokens.join();
    if (text.isEmpty) {
      _log.warning('Gemma returned empty completion');
    }
    _log.info('Gemma text completion done');
    return GemmaCompletionResult(text: text);
  }

  @override
  Stream<String> completeStream(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async* {
    if (_disposed) {
      throw StateError('GemmaBridge has been disposed');
    }
    if (_processing) {
      throw StateError('Gemma is already processing a request');
    }

    _processing = true;
    try {
      await _ensureInitialized();

      final chat = await _getOrCreateTextChat();

      // Merge system prompt + user prompt into a single message to avoid
      // a costly extra round-trip (~4s saved per call).
      final mergedPrompt = systemPrompt != null
          ? '[Instructions]\n$systemPrompt\n\n[Message]\n$prompt'
          : prompt;

      await chat.addQueryChunk(Message.text(
        text: mergedPrompt,
        isUser: true,
      ));

      // generateChatResponseAsync returns Stream<ModelResponse>.
      // Each TextResponse contains a single token.
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Returns a persistent text chat session, reusing the KV cache
  /// between calls for ~2s faster subsequent inferences.
  Future<InferenceChat> _getOrCreateTextChat() async {
    if (_textChat != null) return _textChat!;
    _textChat = await _textModel!.createChat(
      temperature: 0.7,
      topK: 40,
    );
    return _textChat!;
  }

  @override
  Future<GemmaVisionResult> describeImage(
    Uint8List bytes, {
    String? prompt,
  }) async {
    // Delegate to streaming and join all tokens.
    final tokens = <String>[];
    await for (final token in describeImageStream(bytes, prompt: prompt)) {
      tokens.add(token);
    }
    final description = tokens.join();
    if (description.isEmpty) {
      _log.warning('Gemma returned empty image description');
    }
    _log.info('Gemma vision completed');
    return GemmaVisionResult(description: description);
  }

  @override
  Stream<String> describeImageStream(
    Uint8List bytes, {
    String? prompt,
  }) async* {
    if (_disposed) {
      throw StateError('GemmaBridge has been disposed');
    }
    if (_processing) {
      throw StateError('Gemma is already processing a request');
    }

    _processing = true;
    try {
      await _ensureInitialized();

      // Use or create vision model.
      _visionModel ??= await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
        supportImage: true,
        maxNumImages: 1,
      );

      final chat = await _visionModel!.createChat(
        temperature: 0.7,
        topK: 40,
        supportImage: true,
      );

      await chat.addQueryChunk(Message.withImage(
        text: prompt ?? 'Décris cette image en français de manière détaillée.',
        imageBytes: bytes,
        isUser: true,
      ));

      // Stream token-by-token for low-latency TTS.
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } finally {
      _processing = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _textChat = null;
    await _textModel?.close();
    _textModel = null;
    await _visionModel?.close();
    _visionModel = null;
    _log.info('Gemma bridge disposed');
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    _log.info('Initializing Gemma model from assets');
    _status = GemmaModelStatus.loading;

    try {
      await FlutterGemma.initialize();

      // Install from asset if not already installed.
      final installed = await FlutterGemma.isModelInstalled(modelAssetPath);
      if (!installed) {
        _log.info('Installing Gemma model from asset');
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt,
          fileType: ModelFileType.task,
        ).fromAsset(modelAssetPath).install();
      }

      _textModel = await FlutterGemma.getActiveModel(
        maxTokens: 512,
        preferredBackend: PreferredBackend.gpu,
      );

      _initialized = true;
      _status = GemmaModelStatus.ready;
      _log.info('Gemma model ready');
    } on Exception catch (e, stack) {
      _log.error('Gemma initialization failed', error: e, stackTrace: stack);
      _status = GemmaModelStatus.error;
      rethrow;
    }
  }
}
