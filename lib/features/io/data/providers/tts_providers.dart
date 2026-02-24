import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tts_service.dart';
import '../tts_service_impl.dart';

/// Provides the [TTSService] implementation.
final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSServiceImpl();
});
