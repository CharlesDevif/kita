import '../../../core/errors/kita_failure.dart';
import '../../../core/errors/result.dart';
import '../../ai/domain/ai_request.dart';
import '../../ai/domain/ai_response.dart';
import '../../ai/domain/image_data.dart';
import '../../io/domain/location_service.dart';
import '../../io/domain/motion_service.dart';
import '../../plugins/domain/ai_access.dart';
import '../../plugins/domain/sensor_access.dart';

/// Stub [SensorAccess] that always returns [PluginFailure].
///
/// Used as the default delegate in [PluginSandboxImpl] when no real
/// sensor providers are wired (MVP). Agents that actually need sensor
/// data will get proper implementations in a future story.
class StubSensorAccess implements SensorAccess {
  @override
  Future<Result<ImageData>> capturePhoto() async {
    return const Result.failure(PluginFailure(
      userMessage: 'Capteur photo non disponible.',
      logMessage: 'StubSensorAccess: capturePhoto not implemented',
      pluginId: 'system',
    ));
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    return const Result.failure(PluginFailure(
      userMessage: 'Localisation non disponible.',
      logMessage: 'StubSensorAccess: getCurrentPosition not implemented',
      pluginId: 'system',
    ));
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    return const Result.failure(PluginFailure(
      userMessage: 'Capteur mouvement non disponible.',
      logMessage: 'StubSensorAccess: getMotionState not implemented',
      pluginId: 'system',
    ));
  }
}

/// Stub [AIAccess] that always returns [PluginFailure].
///
/// Used as the default delegate in [PluginSandboxImpl] when no real
/// AI providers are wired (MVP). Agents that actually need AI access
/// will get proper implementations in a future story.
class StubAIAccess implements AIAccess {
  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    return const Result.failure(PluginFailure(
      userMessage: 'Service IA non disponible.',
      logMessage: 'StubAIAccess: complete not implemented',
      pluginId: 'system',
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    return const Result.failure(PluginFailure(
      userMessage: 'Service IA vision non disponible.',
      logMessage: 'StubAIAccess: vision not implemented',
      pluginId: 'system',
    ));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt) async* {
    throw const PluginFailure(
      userMessage: 'Service IA vision non disponible.',
      logMessage: 'StubAIAccess: visionStream not implemented',
      pluginId: 'system',
    );
  }
}
