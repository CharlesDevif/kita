import 'dart:async';

import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/utils/logger.dart';
import '../domain/audio_service.dart';
import '../domain/stt_service.dart';

/// Audio channel mode for the multiplexer.
enum AudioMode {
  /// Voice commands via STT (high priority).
  stt,

  /// Ambient sound analysis (low priority).
  ambient,

  /// Microphone not in use.
  idle,
}

/// Implementation of [AudioService] that multiplexes the microphone
/// between STT (voice commands) and ambient analysis.
///
/// STT mode has priority over ambient mode. Switching between modes
/// is transparent and targets < 100ms transition time.
class AudioMultiplexerImpl implements AudioService {
  AudioMultiplexerImpl({
    required STTService sttService,
  }) : _sttService = sttService;

  static final _log = KitaLogger('IO');

  final STTService _sttService;
  AudioMode _currentMode = AudioMode.idle;
  void Function(List<int> audioData)? _ambientCallback;
  bool _listening = false;

  /// The current active mode.
  AudioMode get currentMode => _currentMode;

  @override
  bool get isListening => _listening;

  /// Starts the multiplexer in STT mode (voice commands).
  ///
  /// If ambient mode is active, it is stopped first (STT has priority).
  Future<Result<void>> startSTT({
    required STTResultCallback onResult,
  }) async {
    if (_currentMode == AudioMode.stt) {
      _log.warning('STT already active, ignoring');
      return const Result.success(null);
    }

    // Stop ambient if active — STT has priority.
    if (_currentMode == AudioMode.ambient) {
      _log.info('Switching from ambient to STT mode');
      await _stopAmbientInternal();
    }

    final result = await _sttService.startRecognition(onResult: onResult);

    return result.map((_) {
      _currentMode = AudioMode.stt;
      _listening = true;
      _log.info('AudioMultiplexer: STT mode active');
    });
  }

  /// Stops STT mode. If ambient was previously requested, it can be restarted.
  Future<Result<void>> stopSTT() async {
    if (_currentMode != AudioMode.stt) {
      return const Result.success(null);
    }

    final result = await _sttService.stopRecognition();

    _currentMode = AudioMode.idle;
    _listening = _ambientCallback != null;
    _log.info('AudioMultiplexer: STT mode stopped');

    // Resume ambient if it was requested.
    if (_ambientCallback != null) {
      return _startAmbientInternal(_ambientCallback!);
    }

    return result;
  }

  @override
  Future<Result<void>> startListening({
    void Function(List<int> audioData)? onData,
  }) async {
    if (_currentMode == AudioMode.stt) {
      // STT has priority — queue the ambient request for later.
      _ambientCallback = onData;
      _log.info('Ambient queued — STT has priority');
      return const Result.success(null);
    }

    if (_currentMode == AudioMode.ambient) {
      _log.warning('Ambient already active');
      return const Result.success(null);
    }

    _ambientCallback = onData;
    return _startAmbientInternal(onData);
  }

  @override
  Future<Result<void>> stopListening() async {
    _ambientCallback = null;

    if (_currentMode == AudioMode.ambient) {
      return _stopAmbientInternal();
    }

    return const Result.success(null);
  }

  Future<Result<void>> _startAmbientInternal(
    void Function(List<int> audioData)? onData,
  ) async {
    try {
      _currentMode = AudioMode.ambient;
      _listening = true;
      _log.info('AudioMultiplexer: ambient mode active');
      // In a real implementation, this would start a native audio stream
      // for ambient analysis. For now, the mode is tracked for coordination.
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Ambient start failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Ambient start failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Releases audio multiplexer resources.
  void dispose() {
    _listening = false;
    _currentMode = AudioMode.idle;
    _ambientCallback = null;
  }

  Future<Result<void>> _stopAmbientInternal() async {
    try {
      _currentMode = AudioMode.idle;
      _listening = false;
      _log.info('AudioMultiplexer: ambient mode stopped');
      return const Result.success(null);
    } catch (e, stack) {
      _log.error('Ambient stop failed', error: e, stackTrace: stack);
      return Result.failure(
        UnexpectedFailure(
          logMessage: 'Ambient stop failed: $e',
          cause: e,
          stackTrace: stack,
        ),
      );
    }
  }
}
