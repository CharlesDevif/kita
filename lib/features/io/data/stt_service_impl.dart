import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/stt_service.dart';

/// Implementation of [STTService] using the `speech_to_text` package.
///
/// Provides local speech recognition with French as default language.
/// Supports partial results for responsive UI feedback.
class STTServiceImpl implements STTService {
  STTServiceImpl({
    SpeechToText? speechToText,
    this.localeId = 'fr_FR',
  }) : _speech = speechToText ?? SpeechToText();

  static final _log = KitaLogger('IO');

  final SpeechToText _speech;
  final String localeId;
  bool _initialized = false;
  STTResultCallback? _currentCallback;

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  /// Initializes the speech recognition engine if not already done.
  Future<Result<void>> _ensureInitialized() async {
    if (_initialized) {
      return const Result.success(null);
    }

    try {
      final available = await _speech.initialize(
        onError: (error) {
          _log.warning('STT error: ${error.errorMsg}');
        },
        onStatus: (status) {
          _log.debug('STT status: $status');
        },
      );

      if (!available) {
        _log.warning('Speech recognition not available');
        return Result.failure(
          PermissionFailure.denied('microphone'),
        );
      }

      _initialized = true;
      _log.info('STT initialized, locale: $localeId');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('STT init failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'STT initialization failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> startRecognition({
    required STTResultCallback onResult,
  }) async {
    if (_speech.isListening) {
      _log.warning('STT already listening, ignoring startRecognition');
      return const Result.success(null);
    }

    final initResult = await _ensureInitialized();
    if (initResult.isFailure) {
      return initResult;
    }

    try {
      _currentCallback = onResult;

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _currentCallback?.call(
            result.recognizedWords,
            result.finalResult,
          );
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );

      _log.info('STT listening started');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('STT listen failed', error: e, stackTrace: stack);
      _currentCallback = null;
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'STT listen failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> stopRecognition() async {
    if (!_speech.isListening) {
      return const Result.success(null);
    }

    try {
      await _speech.stop();
      _currentCallback = null;
      _log.info('STT listening stopped');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('STT stop failed', error: e, stackTrace: stack);
      _currentCallback = null;
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'STT stop failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }
}
