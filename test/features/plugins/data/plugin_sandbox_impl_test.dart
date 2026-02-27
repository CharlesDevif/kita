import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/plugins/data/plugin_quota_manager.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:kita/features/plugins/data/sandboxed_ai_access.dart';
import 'package:kita/features/plugins/data/sandboxed_memory_access.dart';
import 'package:kita/features/plugins/data/sandboxed_sensor_access.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/kita_plugin.dart';
import 'package:kita/features/plugins/domain/memory_access.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';

// --- Test Doubles ---

class FakeSensorAccess implements SensorAccess {
  int capturePhotoCount = 0;
  int getPositionCount = 0;
  int getMotionCount = 0;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    capturePhotoCount++;
    return Result.success(ImageData(bytes: Uint8List(0)));
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    getPositionCount++;
    return const Result.success(Position(latitude: 48.8, longitude: 2.3));
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    getMotionCount++;
    return const Result.success(MotionState.immobile);
  }
}

class FakeSensorAccessWithFailure implements SensorAccess {
  @override
  Future<Result<ImageData>> capturePhoto() async {
    return const Result.failure(PermissionFailure(
      userMessage: 'Camera not available.',
      logMessage: 'Camera not available',
      permission: 'camera',
    ));
  }

  @override
  Future<Result<Position>> getCurrentPosition() async =>
      throw UnimplementedError();

  @override
  Future<Result<MotionState>> getMotionState() async =>
      throw UnimplementedError();
}

class FakeAIAccess implements AIAccess {
  int completeCount = 0;
  int visionCount = 0;

  static const _meta = AIResponseMeta(
    providerId: 'test',
    latency: Duration(milliseconds: 100),
    tier: ProviderTier.local,
  );

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    completeCount++;
    return const Result.success(AIResponse(
      content: 'AI response',
      meta: _meta,
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    visionCount++;
    return const Result.success(AIResponse(
      content: 'Vision response',
      meta: _meta,
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt) async* {
    visionCount++;
    yield 'Vision response';
  }
}

class FakeMemoryAccess implements MemoryAccess {
  final Map<String, String> preferences = {};
  final List<KitaEpisode> savedEpisodes = [];

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    savedEpisodes.add(episode);
    return const Result.success(null);
  }

  @override
  Future<Result<String?>> getPreference(String key) async {
    return Result.success(preferences[key]);
  }

  @override
  Future<Result<void>> setPreference(String key, String value) async {
    preferences[key] = value;
    return const Result.success(null);
  }
}

class FakePlugin implements KitaPlugin {
  FakePlugin(this.manifest);

  @override
  final PluginManifest manifest;

  bool activated = false;
  bool deactivated = false;
  PluginRequest? lastRequest;
  bool shouldThrow = false;

  @override
  Future<void> onActivate() async {
    activated = true;
  }

  @override
  Future<void> onDeactivate() async {
    deactivated = true;
  }

  @override
  Future<Result<PluginResponse>> handleRequest(PluginRequest request) async {
    if (shouldThrow) throw StateError('Plugin crashed!');
    lastRequest = request;
    return const Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: 'Plugin result',
    ));
  }

  @override
  Widget? buildViewport(BuildContext context) => null;

  @override
  List<VoiceCommand> get voiceCommands => [];
}

// --- Helper ---

PluginManifest _manifest({
  String id = 'com.kita.test',
  TrustLevel trustLevel = TrustLevel.official,
  List<String> permissions = const ['camera', 'ai.vision', 'ai.text'],
}) {
  return PluginManifest(
    id: id,
    name: 'Test Plugin',
    version: '1.0.0',
    description: 'A test plugin',
    trustLevel: trustLevel,
    permissions: permissions,
  );
}

PluginRequest _request({
  required SensorAccess sensors,
  required AIAccess ai,
  MemoryAccess? memory,
}) {
  return PluginRequest(
    command: 'test',
    sensors: sensors,
    ai: ai,
    memory: memory,
  );
}

void main() {
  group('SandboxedSensorAccess', () {
    late FakeSensorAccess fakeSensors;

    setUp(() {
      fakeSensors = FakeSensorAccess();
    });

    test('allows declared sensor access', () async {
      final proxy = SandboxedSensorAccess(
        delegate: fakeSensors,
        allowedPermissions: {'camera', 'location', 'motion'},
        pluginId: 'com.kita.test',
      );

      expect((await proxy.capturePhoto()).isSuccess, isTrue);
      expect((await proxy.getCurrentPosition()).isSuccess, isTrue);
      expect((await proxy.getMotionState()).isSuccess, isTrue);
      expect(fakeSensors.capturePhotoCount, equals(1));
      expect(fakeSensors.getPositionCount, equals(1));
      expect(fakeSensors.getMotionCount, equals(1));
    });

    test('denies undeclared camera access', () async {
      final proxy = SandboxedSensorAccess(
        delegate: fakeSensors,
        allowedPermissions: {'location'},
        pluginId: 'com.kita.test',
      );

      final result = await proxy.capturePhoto();
      expect(result.isFailure, isTrue);
      expect((result as Failure).failure, isA<PermissionFailure>());
      expect(fakeSensors.capturePhotoCount, equals(0));
    });

    test('denies undeclared location access', () async {
      final proxy = SandboxedSensorAccess(
        delegate: fakeSensors,
        allowedPermissions: {'camera'},
        pluginId: 'com.kita.test',
      );

      final result = await proxy.getCurrentPosition();
      expect(result.isFailure, isTrue);
      expect((result as Failure).failure, isA<PermissionFailure>());
    });

    test('denies undeclared motion access', () async {
      final proxy = SandboxedSensorAccess(
        delegate: fakeSensors,
        allowedPermissions: {},
        pluginId: 'com.kita.test',
      );

      final result = await proxy.getMotionState();
      expect(result.isFailure, isTrue);
      expect((result as Failure).failure, isA<PermissionFailure>());
    });

    test('capturePhoto strips EXIF and returns success on undecodable image', () async {
      // FakeSensorAccess returns empty bytes which cannot be decoded.
      // EXIF stripping should fail gracefully and return the original image.
      final proxy = SandboxedSensorAccess(
        delegate: fakeSensors,
        allowedPermissions: {'camera'},
        pluginId: 'com.kita.test',
      );

      final result = await proxy.capturePhoto();

      // Should still succeed with the original image (graceful fallback)
      expect(result.isSuccess, isTrue);
      final image = (result as Success<ImageData>).value;
      expect(image.bytes.length, equals(0));
    });

    test('capturePhoto returns failure when delegate fails', () async {
      // Create a sensor that fails
      final failingSensors = FakeSensorAccessWithFailure();
      final proxy = SandboxedSensorAccess(
        delegate: failingSensors,
        allowedPermissions: {'camera'},
        pluginId: 'com.kita.test',
      );

      final result = await proxy.capturePhoto();
      expect(result.isFailure, isTrue);
    });
  });

  group('SandboxedAIAccess', () {
    late FakeAIAccess fakeAI;
    late PluginQuotaManager quotaManager;
    late DateTime now;

    setUp(() {
      fakeAI = FakeAIAccess();
      now = DateTime(2026, 1, 1);
      quotaManager = PluginQuotaManager(
        maxCallsPerMinute: 3,
        clock: () => now,
      );
    });

    test('allows AI text access with permission', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.text'},
      );

      final result = await proxy.complete(const AIRequest(prompt: 'test'));
      expect(result.isSuccess, isTrue);
      expect(fakeAI.completeCount, equals(1));
    });

    test('denies AI text access without permission', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.vision'},
      );

      final result = await proxy.complete(const AIRequest(prompt: 'test'));
      expect(result.isFailure, isTrue);
      expect(fakeAI.completeCount, equals(0));
    });

    test('allows AI vision access with permission', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.vision'},
      );

      final result = await proxy.vision(
        ImageData(bytes: Uint8List(0)),
        'describe',
      );
      expect(result.isSuccess, isTrue);
      expect(fakeAI.visionCount, equals(1));
    });

    test('denies AI vision access without permission', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.text'},
      );

      final result = await proxy.vision(
        ImageData(bytes: Uint8List(0)),
        'describe',
      );
      expect(result.isFailure, isTrue);
      expect(fakeAI.visionCount, equals(0));
    });

    test('enforces quota on AI calls', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.text'},
      );

      // 3 calls should succeed
      for (var i = 0; i < 3; i++) {
        final result = await proxy.complete(const AIRequest(prompt: 'test'));
        expect(result.isSuccess, isTrue);
      }

      // 4th call should fail with quota exceeded
      final result = await proxy.complete(const AIRequest(prompt: 'test'));
      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.logMessage, contains('Quota exceeded'));
    });

    test('enforces quota on vision calls', () async {
      final proxy = SandboxedAIAccess(
        delegate: fakeAI,
        pluginId: 'com.kita.test',
        quotaManager: quotaManager,
        allowedPermissions: {'ai.vision'},
      );

      for (var i = 0; i < 3; i++) {
        await proxy.vision(ImageData(bytes: Uint8List(0)), 'test');
      }

      final result = await proxy.vision(
        ImageData(bytes: Uint8List(0)),
        'test',
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('SandboxedMemoryAccess', () {
    late FakeMemoryAccess fakeMemory;

    setUp(() {
      fakeMemory = FakeMemoryAccess();
    });

    test('namespaces preference keys', () async {
      final proxy = SandboxedMemoryAccess(
        delegate: fakeMemory,
        pluginId: 'com.kita.describe',
      );

      await proxy.setPreference('theme', 'dark');

      // The underlying store should have the namespaced key
      expect(
        fakeMemory.preferences.containsKey(
          'plugin_data/com.kita.describe/theme',
        ),
        isTrue,
      );
    });

    test('retrieves namespaced preferences', () async {
      fakeMemory.preferences['plugin_data/com.kita.describe/lang'] = 'fr';

      final proxy = SandboxedMemoryAccess(
        delegate: fakeMemory,
        pluginId: 'com.kita.describe',
      );

      final result = await proxy.getPreference('lang');
      expect(result.isSuccess, isTrue);
      expect((result as Success).value, equals('fr'));
    });

    test('plugins cannot see each other preferences', () async {
      fakeMemory.preferences['plugin_data/com.kita.describe/key'] = 'secret';

      final proxyAlert = SandboxedMemoryAccess(
        delegate: fakeMemory,
        pluginId: 'com.kita.alert',
      );

      // Alert plugin reads with its own namespace — should not find describe's data
      final result = await proxyAlert.getPreference('key');
      expect(result.isSuccess, isTrue);
      expect((result as Success).value, isNull);
    });

    test('saveEpisode delegates to underlying access', () async {
      final proxy = SandboxedMemoryAccess(
        delegate: fakeMemory,
        pluginId: 'com.kita.describe',
      );

      final episode = KitaEpisode(
        id: 1,
        source: 'test',
        eventType: 'test',
        summary: 'Test episode',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      final result = await proxy.saveEpisode(episode);
      expect(result.isSuccess, isTrue);
      expect(fakeMemory.savedEpisodes, hasLength(1));
    });
  });

  group('PluginSandboxImpl', () {
    late FakeSensorAccess fakeSensors;
    late FakeAIAccess fakeAI;
    late FakeMemoryAccess fakeMemory;
    late PluginQuotaManager quotaManager;
    late PluginSandboxImpl sandbox;

    setUp(() {
      fakeSensors = FakeSensorAccess();
      fakeAI = FakeAIAccess();
      fakeMemory = FakeMemoryAccess();
      quotaManager = PluginQuotaManager(
        maxCallsPerMinute: 10,
        clock: () => DateTime(2026, 1, 1),
      );
      sandbox = PluginSandboxImpl(
        sensorAccess: fakeSensors,
        aiAccess: fakeAI,
        memoryAccess: fakeMemory,
        quotaManager: quotaManager,
      );
    });

    test('executes plugin with sandboxed request', () async {
      final manifest = _manifest(trustLevel: TrustLevel.official);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = await sandbox.execute(plugin, request);

      expect(result.isSuccess, isTrue);
      expect(plugin.lastRequest, isNotNull);
      // The request passed to the plugin should have sandboxed proxies
      expect(plugin.lastRequest!.sensors, isA<SandboxedSensorAccess>());
      expect(plugin.lastRequest!.ai, isA<SandboxedAIAccess>());
    });

    test('official plugin gets shared memory access', () async {
      final manifest = _manifest(trustLevel: TrustLevel.official);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      await sandbox.execute(plugin, request);

      // Official plugins get the raw memory access (not sandboxed)
      expect(plugin.lastRequest!.memory, equals(fakeMemory));
    });

    test('community verified plugin gets sandboxed memory', () async {
      final manifest = _manifest(trustLevel: TrustLevel.communityVerified);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      await sandbox.execute(plugin, request);

      expect(plugin.lastRequest!.memory, isA<SandboxedMemoryAccess>());
    });

    test('unverified plugin gets no memory access', () async {
      final manifest = _manifest(trustLevel: TrustLevel.unverified);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      await sandbox.execute(plugin, request);

      expect(plugin.lastRequest!.memory, isNull);
    });

    test('catches plugin crashes and returns PluginFailure', () async {
      final manifest = _manifest();
      final plugin = FakePlugin(manifest)..shouldThrow = true;
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = await sandbox.execute(plugin, request);

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.logMessage, contains('crashed'));
    });

    test('sensor access is scoped to declared permissions', () async {
      // Plugin only declares 'camera', not 'location'
      final manifest = _manifest(permissions: ['camera']);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      await sandbox.execute(plugin, request);

      final sandboxedSensors =
          plugin.lastRequest!.sensors as SandboxedSensorAccess;

      // Camera should work
      expect((await sandboxedSensors.capturePhoto()).isSuccess, isTrue);

      // Location should be denied
      expect((await sandboxedSensors.getCurrentPosition()).isFailure, isTrue);
    });

    test('AI access is scoped to declared permissions', () async {
      // Plugin only declares 'ai.vision', not 'ai.text'
      final manifest = _manifest(permissions: ['ai.vision']);
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      await sandbox.execute(plugin, request);

      final sandboxedAI = plugin.lastRequest!.ai as SandboxedAIAccess;

      // Vision should work
      expect(
        (await sandboxedAI.vision(ImageData(bytes: Uint8List(0)), 'test'))
            .isSuccess,
        isTrue,
      );

      // Text should be denied
      expect(
        (await sandboxedAI.complete(const AIRequest(prompt: 'test')))
            .isFailure,
        isTrue,
      );
    });

    test('enforcePermissions returns success (structural check)', () {
      final manifest = _manifest();
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = sandbox.enforcePermissions(manifest, request);
      expect(result.isSuccess, isTrue);
    });
  });

  group('Integration: full sandbox lifecycle per trust level', () {
    late FakeSensorAccess fakeSensors;
    late FakeAIAccess fakeAI;
    late FakeMemoryAccess fakeMemory;
    late PluginSandboxImpl sandbox;

    setUp(() {
      fakeSensors = FakeSensorAccess();
      fakeAI = FakeAIAccess();
      fakeMemory = FakeMemoryAccess();
      sandbox = PluginSandboxImpl(
        sensorAccess: fakeSensors,
        aiAccess: fakeAI,
        memoryAccess: fakeMemory,
      );
    });

    test('official plugin: full access', () async {
      final manifest = _manifest(
        id: 'com.kita.describe',
        trustLevel: TrustLevel.official,
        permissions: ['camera', 'ai.vision', 'ai.text'],
      );
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = await sandbox.execute(plugin, request);
      expect(result.isSuccess, isTrue);

      // All access should work
      final req = plugin.lastRequest!;
      expect((await req.sensors.capturePhoto()).isSuccess, isTrue);
      expect(
        (await req.ai.vision(ImageData(bytes: Uint8List(0)), 'test'))
            .isSuccess,
        isTrue,
      );
      expect(
        (await req.ai.complete(const AIRequest(prompt: 'test'))).isSuccess,
        isTrue,
      );
      expect(req.memory, isNotNull);
      expect(req.memory, equals(fakeMemory)); // shared, not sandboxed
    });

    test('community plugin: sandboxed memory', () async {
      final manifest = _manifest(
        id: 'org.community.reader',
        trustLevel: TrustLevel.communityVerified,
        permissions: ['ai.text'],
      );
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = await sandbox.execute(plugin, request);
      expect(result.isSuccess, isTrue);

      final req = plugin.lastRequest!;
      // Memory should be sandboxed
      expect(req.memory, isA<SandboxedMemoryAccess>());

      // Camera denied (not declared)
      expect((await req.sensors.capturePhoto()).isFailure, isTrue);

      // AI text allowed
      expect(
        (await req.ai.complete(const AIRequest(prompt: 'test'))).isSuccess,
        isTrue,
      );
    });

    test('unverified plugin: no memory, limited access', () async {
      final manifest = _manifest(
        id: 'org.unknown.test.plugin',
        trustLevel: TrustLevel.unverified,
        permissions: ['camera'],
      );
      final plugin = FakePlugin(manifest);
      final request = _request(sensors: fakeSensors, ai: fakeAI);

      final result = await sandbox.execute(plugin, request);
      expect(result.isSuccess, isTrue);

      final req = plugin.lastRequest!;
      // No memory
      expect(req.memory, isNull);

      // Camera allowed
      expect((await req.sensors.capturePhoto()).isSuccess, isTrue);

      // AI text denied (not declared)
      expect(
        (await req.ai.complete(const AIRequest(prompt: 'test'))).isFailure,
        isTrue,
      );
    });
  });
}
