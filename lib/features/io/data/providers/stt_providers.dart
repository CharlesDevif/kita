import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/stt_service.dart';
import '../stt_service_impl.dart';

/// Provides the [STTService] implementation.
final sttServiceProvider = Provider<STTService>((ref) {
  return STTServiceImpl();
});
