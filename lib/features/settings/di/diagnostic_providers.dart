import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/data/providers/gemma_bridge.dart';
import '../../orchestration/di/providers.dart';

/// Exposes the current Gemma model status for the diagnostic screen.
final gemmaStatusProvider =
    FutureProvider.autoDispose<GemmaModelStatus>((ref) {
  final bridge = ref.watch(gemmaBridgeProvider);
  return bridge.checkStatus();
});
