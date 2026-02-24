import '../../../core/errors/result.dart';

typedef STTResultCallback = void Function(String transcript, bool isFinal);

/// Speech-to-text recognition service.
///
/// Minimal interface by design — initialization and locale configuration
/// are implementation details handled internally.
abstract interface class STTService {
  bool get isAvailable;
  bool get isListening;
  Future<Result<void>> startRecognition({required STTResultCallback onResult});
  Future<Result<void>> stopRecognition();
}
