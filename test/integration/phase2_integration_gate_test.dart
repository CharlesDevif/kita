import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/onboarding/di/providers.dart';
import 'package:kita/features/orchestration/di/providers.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:kita/core/data/database.dart' hide UserProfile;
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/memory/domain/forget_request.dart';
import 'package:kita/features/ai/data/ai_router_impl.dart';
import 'package:kita/features/ai/data/request_classifier_impl.dart';
import 'package:kita/features/ai/domain/ai_provider.dart';
import 'package:kita/features/ai/domain/ai_request.dart';
import 'package:kita/features/ai/domain/ai_response.dart';
import 'package:kita/features/ai/domain/image_data.dart';
import 'package:kita/features/ai/domain/provider_tier.dart';
import 'package:kita/features/ai/domain/tool_models.dart';
import 'package:kita/features/io/domain/location_service.dart';
import 'package:kita/features/io/domain/motion_service.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/plugins/data/plugin_registry.dart';
import 'package:kita/features/plugins/domain/ai_access.dart';
import 'package:kita/features/plugins/domain/kita_plugin.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/sensor_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';
import 'package:kita/features/shell/domain/orb_state.dart';
import 'package:kita/features/shell/presentation/kita_orb.dart';
import 'package:kita/features/shell/presentation/kita_shell.dart';
import 'package:kita/shared/multi_modal/profile_adapter_impl.dart';

// =============================================================================
// Mock implementations for integration testing
// =============================================================================

class _MockAIProvider implements AIProvider {
  _MockAIProvider({
    required this.id,
    required this.displayName,
    required this.tier,
    this.isAvailable = true, // ignore: unused_element_parameter
    this.responseContent = 'Reponse mock du provider',
    this.shouldFail = false,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final ProviderTier tier;
  @override
  final bool isAvailable;

  final String responseContent;
  final bool shouldFail;

  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur provider',
          logMessage: 'Mock failure',
        ),
      );
    }
    return Result.success(AIResponse(
      content: responseContent,
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 50),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt, {int? maxTokens}) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur vision',
          logMessage: 'Mock failure',
        ),
      );
    }
    return Result.success(AIResponse(
      content: 'Description de l\'image: $prompt',
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 100),
        tier: tier,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> completeStream(AIRequest request) {
    return batchCompleteAsStream(() => complete(request));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt, {int? maxTokens}) {
    return batchVisionAsStream(() => vision(image, prompt, maxTokens: maxTokens));
  }

  @override
  Future<Result<AIToolResponse>> completeWithTools(
    AIRequest request, {
    required List<ToolSpec> tools,
    List<ConversationMessage> history = const [],
  }) async {
    if (shouldFail) {
      return const Result.failure(
        AIProviderFailure(
          userMessage: 'Erreur provider',
          logMessage: 'Mock failure',
        ),
      );
    }
    return Result.success(AIToolResponse(
      text: responseContent,
      meta: AIResponseMeta(
        providerId: id,
        latency: const Duration(milliseconds: 50),
        tier: tier,
      ),
    ));
  }

  @override
  Future<Result<void>> validateApiKey(String key) async {
    return const Result.success(null);
  }
}

class _MockSensorAccess implements SensorAccess {
  bool capturePhotoCalled = false;

  @override
  Future<Result<ImageData>> capturePhoto() async {
    capturePhotoCalled = true;
    return Result.success(ImageData(
      bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]),
      mimeType: 'image/jpeg',
      width: 640,
      height: 480,
    ));
  }

  @override
  Future<Result<Position>> getCurrentPosition() async {
    return const Result.success(Position(latitude: 48.8566, longitude: 2.3522));
  }

  @override
  Future<Result<MotionState>> getMotionState() async {
    return const Result.success(MotionState.walking);
  }
}

class _MockAIAccess implements AIAccess {
  @override
  Future<Result<AIResponse>> complete(AIRequest request) async {
    return const Result.success(AIResponse(
      content: 'Reponse IA pour plugin',
      meta: AIResponseMeta(
        providerId: 'mock-ai',
        latency: Duration(milliseconds: 10),
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Future<Result<AIResponse>> vision(ImageData image, String prompt) async {
    return const Result.success(AIResponse(
      content: 'Photo: un trottoir avec des pietons',
      meta: AIResponseMeta(
        providerId: 'mock-ai',
        latency: Duration(milliseconds: 20),
        tier: ProviderTier.local,
      ),
      status: AIResponseStatus.success,
    ));
  }

  @override
  Stream<String> visionStream(ImageData image, String prompt) async* {
    yield 'Photo: un trottoir avec des pietons';
  }
}

class _MockDescribePlugin extends KitaPlugin {
  bool activated = false;
  bool deactivated = false;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: 'com.kita.describe',
        name: 'Kita Describe',
        version: '1.0.0',
        description: 'Description vocale de scenes',
        trustLevel: TrustLevel.official,
        permissions: ['sensor.camera', 'ai.vision'],
        capabilities: ['photo_description'],
        compatibleProfiles: ['aveugle', 'standard'],
        voiceCommands: ['decris', 'describe'],
      );

  @override
  List<VoiceCommand> get voiceCommands => [
        const VoiceCommand(
          trigger: 'decris',
          description: 'Decrit la scene devant toi',
          aliases: ['describe', 'c\'est quoi'],
        ),
      ];

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
    final photoResult = await request.sensors.capturePhoto();
    if (photoResult.isFailure) {
      return const Result.failure(PluginFailure(
        userMessage: 'Impossible de prendre la photo',
        logMessage: 'capturePhoto failed',
        pluginId: 'com.kita.describe',
      ));
    }

    final visionResult = await request.ai.vision(
      photoResult.getOrElse((_) => throw StateError('unreachable')),
      'Decris cette scene',
    );

    return visionResult.map((response) => PluginResponse(
          type: PluginResponseType.text,
          content: response.content,
        ));
  }

  @override
  Widget? buildViewport(BuildContext context) => null;
}

// =============================================================================
// Integration Gate Tests — Story 2.8
// =============================================================================

void main() {
  // -------------------------------------------------------------------------
  // Test 1 : Smoke — Shell + Orb + AIRouter
  // -------------------------------------------------------------------------
  group('Smoke test: Shell renders and AIRouter processes text', () {
    testWidgets('KitaShell renders with KitaOrb', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasActiveOnDemandProvider.overrideWithValue(false),
            onboardingCompleteProvider
                .overrideWith(_CompletedOnboarding.new),
          ],
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: KitaShell(
                orbStateOverride: OrbState.passive,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Shell renders
      expect(find.byType(KitaShell), findsOneWidget);
      // Orb renders inside shell
      expect(find.byType(KitaOrb), findsOneWidget);
    });

    test('AIRouter routes text request through mock provider', () async {
      final classifier = RequestClassifierImpl();
      final mockProvider = _MockAIProvider(
        id: 'mock-local',
        displayName: 'Mock Local',
        tier: ProviderTier.local,
        responseContent: 'Il fait beau aujourd\'hui',
      );

      final router = AIRouterImpl(
        classifier: classifier,
        providers: [mockProvider],
      );

      final result = await router.route(
        const AIRequest(prompt: 'Quel temps fait-il ?'),
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          expect(response.content, contains('beau'));
          expect(response.meta.providerId, 'mock-local');
        },
        failure: (_) => fail('Expected success'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Test 2 : Chaine IA — Vision → Provider → ProfileAdapter → output
  // -------------------------------------------------------------------------
  group('AI chain: vision request through router and ProfileAdapter', () {
    test('vision request → mock provider → ProfileAdapter routes output',
        () async {
      final classifier = RequestClassifierImpl();
      final cloudProvider = _MockAIProvider(
        id: 'mock-claude',
        displayName: 'Mock Claude',
        tier: ProviderTier.cloudPowerful,
        responseContent: 'Un parc avec des arbres et un banc',
      );

      final router = AIRouterImpl(
        classifier: classifier,
        providers: [cloudProvider],
      );

      // Route a vision-like request (text with image context)
      final result = await router.route(
        AIRequest(
          prompt: 'Decris cette image',
          imageData: ImageData(
            bytes: Uint8List.fromList([0xFF, 0xD8]),
            width: 320,
            height: 240,
          ),
        ),
      );

      expect(result.isSuccess, isTrue);
      final response = result.getOrElse((_) => throw StateError('fail'));

      // ProfileAdapter routes to correct modalities for blind user
      final adapter = ProfileAdapterImpl(profile: UserProfile.aveugle);
      bool vocalCalled = false;
      bool hapticCalled = false;
      bool visualCalled = false;

      adapter.feedback(
        visual: () => visualCalled = true,
        vocal: () => vocalCalled = true,
        haptic: () => hapticCalled = true,
      );

      // Blind profile: vocal + haptic, NO visual
      expect(vocalCalled, isTrue);
      expect(hapticCalled, isTrue);
      expect(visualCalled, isFalse);
      // FallbackChain calls vision() when imageData present
      expect(response.content, contains('Decris cette image'));
    });

    test('fallback chain never fails — brute alert on all providers down',
        () async {
      final classifier = RequestClassifierImpl();
      final failingProvider = _MockAIProvider(
        id: 'mock-failing',
        displayName: 'Failing Provider',
        tier: ProviderTier.cloudPowerful,
        shouldFail: true,
      );

      final router = AIRouterImpl(
        classifier: classifier,
        providers: [failingProvider],
      );

      final result = await router.route(
        const AIRequest(prompt: 'aide-moi urgent danger'),
      );

      // FallbackChain guarantees a result even if all providers fail
      expect(result.isSuccess, isTrue);
      result.when(
        success: (response) {
          // Brute alert uses .degraded status
          expect(response.status, AIResponseStatus.degraded);
        },
        failure: (_) => fail('FallbackChain should never fail'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Test 3 : Plugin + Capteurs — Registry + SensorAccess
  // -------------------------------------------------------------------------
  group('Plugin-sensors: registry loads plugin, plugin captures photo', () {
    test('plugin registers, activates, and calls capturePhoto via sensor',
        () async {
      final registry = PluginRegistryImpl();
      final plugin = _MockDescribePlugin();
      final sensors = _MockSensorAccess();
      final ai = _MockAIAccess();

      // Register and activate
      final regResult = registry.register(plugin);
      expect(regResult.isSuccess, isTrue);

      final actResult = await registry.activate('com.kita.describe');
      expect(actResult.isSuccess, isTrue);
      expect(plugin.activated, isTrue);

      // Plugin is accessible
      final activePlugin = registry.getPlugin('com.kita.describe');
      expect(activePlugin, isNotNull);

      // Voice commands aggregated
      expect(registry.aggregatedVoiceCommands.length, 1);
      expect(registry.aggregatedVoiceCommands.first.trigger, 'decris');

      // Execute plugin request with sensor access
      final response = await plugin.handleRequest(PluginRequest(
        command: 'describe',
        sensors: sensors,
        ai: ai,
      ));

      expect(sensors.capturePhotoCalled, isTrue);
      expect(response.isSuccess, isTrue);
      response.when(
        success: (resp) {
          expect(resp.type, PluginResponseType.text);
          expect(resp.content, contains('trottoir'));
        },
        failure: (_) => fail('Expected plugin success'),
      );

      // Deactivate
      final deactResult = await registry.deactivate('com.kita.describe');
      expect(deactResult.isSuccess, isTrue);
      expect(plugin.deactivated, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Test 4 : Memoire reelle — Drift DB (pas de mock)
  // -------------------------------------------------------------------------
  group('Real memory: MemoryVault with real Drift database', () {
    late KitaDatabase db;
    late MemoryVaultImpl vault;
    late ConsentDao consentDao;

    setUp(() {
      final rawDb = sql.sqlite3.openInMemory();
      db = KitaDatabase(NativeDatabase.opened(rawDb));

      final episodeDao = EpisodeDao(db);
      final preferenceDao = PreferenceDao(db);
      final personDao = PersonDao(db);
      final profileDao = ProfileDao(db);
      final pluginDataDao = PluginDataDao(db);
      consentDao = ConsentDao(db);

      vault = MemoryVaultImpl(
        episodeDao: episodeDao,
        preferenceDao: preferenceDao,
        personDao: personDao,
        profileDao: profileDao,
        pluginDataDao: pluginDataDao,
        consentDao: consentDao,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('saveEpisode + whatDoYouKnow round-trip with real DB', () async {
      // Grant consent first
      await consentDao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );

      // Save episode
      final episode = KitaEpisode(
        id: 0,
        source: 'integration_test',
        eventType: 'description',
        summary: 'Un parc avec des arbres devant l\'utilisateur',
        details: 'Photo prise a 14h30, 3 arbres, 1 banc, soleil',
        tags: ['exterieur', 'parc'],
        importanceScore: 0.7,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      final saveResult = await vault.saveEpisode(episode);
      expect(saveResult.isSuccess, isTrue);

      // whatDoYouKnow returns the episode
      final knowResult = await vault.whatDoYouKnow();
      expect(knowResult.isSuccess, isTrue);

      knowResult.when(
        success: (data) {
          expect(data.containsKey(MemoryDomain.episodic), isTrue);
          expect(data[MemoryDomain.episodic]!.length, 1);
          expect(data[MemoryDomain.episodic]!.first, contains('parc'));
        },
        failure: (_) => fail('Expected success'),
      );
    });

    test('consent required — saveEpisode fails without consent', () async {
      final episode = KitaEpisode(
        id: 0,
        source: 'test',
        eventType: 'test',
        summary: 'Test sans consentement',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      );

      final result = await vault.saveEpisode(episode);
      expect(result.isFailure, isTrue);
    });

    test('forget + audit: data is fully erased with real DB', () async {
      // Grant consent
      await consentDao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );

      // Save data
      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'test',
        eventType: 'test',
        summary: 'Donnee a effacer',
        importanceScore: 0.5,
        isPinned: false,
        createdAt: DateTime.now(),
      ));

      // Verify data exists
      final before = await vault.whatDoYouKnow();
      expect(before.getOrElse((_) => {}).containsKey(MemoryDomain.episodic),
          isTrue);

      // Forget domain
      final forgetResult = await vault.forget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );
      expect(forgetResult.isSuccess, isTrue);

      // Audit: no residual data
      final auditResult = await vault.auditForget(
        ForgetRequest.domain(MemoryDomain.episodic, confirmation: true),
      );
      expect(auditResult.isSuccess, isTrue);
      expect(auditResult.getOrElse((_) => false), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Test 5 : ProfileAdapter — routing par profil
  // -------------------------------------------------------------------------
  group('ProfileAdapter routes outputs per accessibility profile', () {
    test('aveugle (blind): vocal + haptic, NO visual', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.aveugle);
      bool v = false, a = false, h = false;
      adapter.feedback(
        visual: () => v = true,
        vocal: () => a = true,
        haptic: () => h = true,
      );
      expect(v, isFalse);
      expect(a, isTrue);
      expect(h, isTrue);
    });

    test('sourd (deaf): visual + haptic, NO vocal', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.sourd);
      bool v = false, a = false, h = false;
      adapter.feedback(
        visual: () => v = true,
        vocal: () => a = true,
        haptic: () => h = true,
      );
      expect(v, isTrue);
      expect(a, isFalse);
      expect(h, isTrue);
    });

    test('standard: all modalities active', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.standard);
      bool v = false, a = false, h = false;
      adapter.feedback(
        visual: () => v = true,
        vocal: () => a = true,
        haptic: () => h = true,
      );
      expect(v, isTrue);
      expect(a, isTrue);
      expect(h, isTrue);
    });

    test('aidant (caregiver): visual + haptic, NO vocal', () {
      final adapter = ProfileAdapterImpl(profile: UserProfile.aidant);
      bool v = false, a = false, h = false;
      adapter.feedback(
        visual: () => v = true,
        vocal: () => a = true,
        haptic: () => h = true,
      );
      expect(v, isTrue);
      expect(a, isFalse);
      expect(h, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Test 6 : Cross-feature — AI + Memory + Plugin + ProfileAdapter
  // -------------------------------------------------------------------------
  group('Cross-feature integration: full pipeline', () {
    late KitaDatabase db;
    late MemoryVaultImpl vault;

    setUp(() {
      final rawDb = sql.sqlite3.openInMemory();
      db = KitaDatabase(NativeDatabase.opened(rawDb));
      vault = MemoryVaultImpl(
        episodeDao: EpisodeDao(db),
        preferenceDao: PreferenceDao(db),
        personDao: PersonDao(db),
        profileDao: ProfileDao(db),
        pluginDataDao: PluginDataDao(db),
        consentDao: ConsentDao(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
        'full pipeline: classify → route → plugin → capture → vault → ProfileAdapter',
        () async {
      // 1. AIRouter classifies and routes
      final router = AIRouterImpl(
        classifier: RequestClassifierImpl(),
        providers: [
          _MockAIProvider(
            id: 'local-ml',
            displayName: 'Local ML',
            tier: ProviderTier.local,
            responseContent: 'Un passage pieton avec feu rouge',
          ),
        ],
      );

      final aiResult = await router.route(
        const AIRequest(prompt: 'decris ce que tu vois'),
      );
      expect(aiResult.isSuccess, isTrue);

      // 2. Plugin captures photo via sensors
      final sensors = _MockSensorAccess();
      final photoResult = await sensors.capturePhoto();
      expect(photoResult.isSuccess, isTrue);
      expect(sensors.capturePhotoCalled, isTrue);

      // 3. Save interaction as episode in real DB
      final consentDao = ConsentDao(db);
      await consentDao.insert(
        consentType: 'data_storage',
        scope: 'episodic',
        granted: true,
      );

      final content =
          aiResult.getOrElse((_) => throw StateError('fail')).content;

      await vault.saveEpisode(KitaEpisode(
        id: 0,
        source: 'com.kita.describe',
        eventType: 'description',
        summary: content,
        importanceScore: 0.8,
        isPinned: false,
        createdAt: DateTime.now(),
      ));

      // 4. Verify memory has the episode
      final knowResult = await vault.whatDoYouKnow();
      expect(knowResult.isSuccess, isTrue);
      final data = knowResult.getOrElse((_) => {});
      expect(data[MemoryDomain.episodic]?.first, contains('passage pieton'));

      // 5. ProfileAdapter routes the response
      final adapter = ProfileAdapterImpl(profile: UserProfile.aveugle);
      bool ttsTriggered = false;
      bool hapticTriggered = false;

      adapter.feedback(
        vocal: () => ttsTriggered = true,
        haptic: () => hapticTriggered = true,
      );

      expect(ttsTriggered, isTrue);
      expect(hapticTriggered, isTrue);
    });
  });
}

/// Notifier that starts with onboarding already complete.
class _CompletedOnboarding extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}
