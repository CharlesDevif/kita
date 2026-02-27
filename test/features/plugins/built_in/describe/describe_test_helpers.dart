import 'dart:typed_data';

import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';

// --- Mocks ---

class MockSensorAccess implements SensorAccess {
  ImageData? photoToReturn;
  KitaFailure? failureToReturn;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    if (failureToReturn != null) return Result.failure(failureToReturn!);
    return Result.success(photoToReturn!);
  }

  @override
  Future<Result<Position>> getCurrentPosition() async =>
      throw UnimplementedError();

  @override
  Future<Result<MotionState>> getMotionState() async =>
      throw UnimplementedError();
}

class MockAIAccess implements AIAccess {
  AIResponse? responseToReturn;
  KitaFailure? failureToReturn;
  ImageData? lastImageReceived;
  String? lastPromptReceived;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async =>
      throw UnimplementedError();

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    lastImageReceived = image;
    lastPromptReceived = prompt;
    if (failureToReturn != null) return Result.failure(failureToReturn!);
    return Result.success(responseToReturn!);
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt) async* {
    lastImageReceived = image;
    lastPromptReceived = prompt;
    if (failureToReturn != null) throw failureToReturn!;
    yield responseToReturn!.content;
  }
}

// --- Helpers ---

/// Minimal valid JPEG bytes (SOI + APP0 + EOI markers).
Uint8List minimalJpeg() =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xD9]);

ImageData testImage() =>
    ImageData(bytes: minimalJpeg(), mimeType: 'image/jpeg');

AIResponse testAIResponse({
  String content = 'Un salon lumineux avec un canape bleu.',
  AIResponseStatus status = AIResponseStatus.success,
}) =>
    AIResponse(
      content: content,
      meta: const AIResponseMeta(
        providerId: 'claude',
        latency: Duration(milliseconds: 2500),
        tier: ProviderTier.cloudPowerful,
      ),
      status: status,
    );

PluginRequest testRequest(
  MockSensorAccess sensors,
  MockAIAccess ai, {
  String command = 'decris',
}) =>
    PluginRequest(command: command, sensors: sensors, ai: ai);
