import '../../../core/errors/result.dart';

abstract interface class AudioService {
  bool get isListening;
  Future<Result<void>> startListening({
    void Function(List<int> audioData)? onData,
  });
  Future<Result<void>> stopListening();
}
