import 'dart:async' show unawaited;
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/tts_service.dart';

/// A queued speech request with priority.
class _SpeechRequest implements Comparable<_SpeechRequest> {
  _SpeechRequest(this.text, this.priority);

  final String text;
  final TTSPriority priority;

  @override
  int compareTo(_SpeechRequest other) {
    // Lower index = higher priority (critical=0, urgent=1, standard=2).
    final cmp = priority.index.compareTo(other.priority.index);
    // SplayTreeSet uses comparison for equality — break ties with hashCode.
    return cmp != 0 ? cmp : hashCode.compareTo(other.hashCode);
  }
}

/// Implementation of [TTSService] using the `flutter_tts` package.
///
/// Features a priority queue where critical messages interrupt standard ones.
/// Priority order: critical > urgent > standard.
///
/// [speak] enqueues the message and returns immediately. The queue is
/// processed asynchronously via the completion handler.
class TTSServiceImpl implements TTSService {
  TTSServiceImpl({
    FlutterTts? flutterTts,
    this.language = 'fr-FR',
  }) : _tts = flutterTts ?? FlutterTts();

  static final _log = KitaLogger('IO');

  final FlutterTts _tts;
  final String language;
  bool _initialized = false;

  final SplayTreeSet<_SpeechRequest> _queue =
      SplayTreeSet<_SpeechRequest>();

  _SpeechRequest? _currentRequest;
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  /// The priority of the currently speaking message, if any.
  TTSPriority? get currentPriority => _currentRequest?.priority;

  /// Number of messages waiting in the queue.
  int get queueLength => _queue.length;

  Future<Result<void>> _ensureInitialized() async {
    if (_initialized) {
      return const Result.success(null);
    }

    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);

      _tts.setCompletionHandler(_onSpeechComplete);

      _initialized = true;
      _log.info('TTS initialized, language: $language');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('TTS init failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'TTS initialization failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<void>> speak(
    String text, {
    TTSPriority priority = TTSPriority.standard,
  }) async {
    final initResult = await _ensureInitialized();
    if (initResult.isFailure) {
      return initResult;
    }

    final request = _SpeechRequest(text, priority);

    // If a higher-priority message needs to interrupt a lower-priority one:
    if (_speaking && _currentRequest != null) {
      if (priority.index < _currentRequest!.priority.index) {
        _log.info(
          'Interrupting ${_currentRequest!.priority.name} with ${priority.name}',
        );
        await _tts.stop();
        // Re-queue the interrupted request.
        _queue.add(_currentRequest!);
        _currentRequest = null;
        _speaking = false;
      }
    }

    _queue.add(request);
    await _processQueue();

    return const Result.success(null);
  }

  @override
  Future<Result<void>> stop() async {
    try {
      _queue.clear();
      _currentRequest = null;

      await _tts.stop();
      _speaking = false;
      _log.info('TTS stopped');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('TTS stop failed', error: e, stackTrace: stack);
      _speaking = false;
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'TTS stop failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<void> _processQueue() async {
    if (_speaking || _queue.isEmpty) return;

    _currentRequest = _queue.first;
    _queue.remove(_currentRequest);
    _speaking = true;

    _log.debug('Speaking (${_currentRequest!.priority.name}): '
        '${_currentRequest!.text.length} chars');

    try {
      await _tts.speak(_currentRequest!.text);
    } catch (e, stack) {
      _log.error('TTS speak error', error: e, stackTrace: stack);
      _speaking = false;
      _currentRequest = null;
    }
  }

  void _onSpeechComplete() {
    _currentRequest = null;
    _speaking = false;
    unawaited(_processQueue());
  }

  /// Releases TTS resources, stops playback and clears the queue.
  void dispose() {
    _queue.clear();
    _currentRequest = null;
    _speaking = false;
    // Don't call _tts.stop() if not initialized
    if (_initialized) {
      _tts.stop();
    }
  }
}
