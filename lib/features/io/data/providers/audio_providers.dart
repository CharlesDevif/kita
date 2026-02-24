import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio_service.dart';
import '../audio_service_impl.dart';
import 'stt_providers.dart';

/// Provides the [AudioService] implementation (AudioMultiplexer).
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioMultiplexerImpl(
    sttService: ref.watch(sttServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
