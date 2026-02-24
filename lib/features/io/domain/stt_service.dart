import '../../../core/errors/result.dart';

typedef STTResultCallback = void Function(String transcript, bool isFinal);

abstract interface class STTService {
  bool get isAvailable;
  bool get isListening;
  Future<Result<void>> startRecognition({required STTResultCallback onResult});
  Future<Result<void>> stopRecognition();
}
