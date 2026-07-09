import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/data/database.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/core/utils/logger.dart';
import 'package:kita/features/io/domain/haptic_service.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_consent.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/domain/memory_vault.dart';
import 'package:kita/features/orchestration/domain/agent_bus.dart';
import 'package:kita/features/orchestration/domain/clock.dart';
import 'package:kita/features/orchestration/domain/kita_agent.dart';
import 'package:kita/features/orchestration/domain/models/agent_input.dart';
import 'package:kita/features/orchestration/domain/models/agent_manifest.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';
import 'package:kita/features/orchestration/domain/models/agent_output.dart';
import 'package:kita/features/orchestration/domain/models/output_priority.dart';
import 'package:kita/features/orchestration/domain/output_handle.dart';
import 'package:kita/features/plugins/built_in/describe/describe_plugin.dart';
import 'package:kita/features/plugins/data/vault_memory_access.dart';
import 'package:kita/features/plugins/domain/memory_access.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'describe_test_helpers.dart';

// === Fake MemoryAccess ===

/// Fake [MemoryAccess] capturant les épisodes écrits, avec possibilité de
/// simuler un échec d'écriture (le vault est plein, verrouillé, etc.).
class FakeMemoryAccess implements MemoryAccess {
  final List<KitaEpisode> savedEpisodes = [];

  /// Si non-null, saveEpisode renvoie cette failure au lieu de capturer
  /// l'épisode.
  KitaFailure? saveEpisodeFailure;

  @override
  Future<Result<void>> saveEpisode(KitaEpisode episode) async {
    if (saveEpisodeFailure != null) {
      return Result.failure(saveEpisodeFailure!);
    }
    savedEpisodes.add(episode);
    return const Result.success(null);
  }

  @override
  Future<Result<String?>> getPreference(String key) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> setPreference(String key, String value) async =>
      throw UnimplementedError();
}

// === Mock OutputHandle ===

class MockOutputHandle implements OutputHandle {
  MockOutputHandle({required this.agentId});

  @override
  final String agentId;

  final List<({String text, OutputPriority priority})> speakCalls = [];

  final StreamController<SpeechEvent> speechEventsController =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get speechEvents => speechEventsController.stream;

  @override
  Future<void> speak(String text,
      {OutputPriority priority = OutputPriority.standard,
      double? distance,
      String? cooldownKey}) async {
    speakCalls.add((text: text, priority: priority));
  }

  @override
  Future<void> haptic(HapticPattern pattern,
      {OutputPriority priority = OutputPriority.standard}) async {}

  @override
  void updateViewport(Widget widget) {}

  @override
  void complete() {}

  void dispose() {
    speechEventsController.close();
  }
}

class MockAgentBus implements AgentBus {
  @override
  void publish(AgentMessage message) {}
  @override
  void subscribe(String agentId, Set<AgentMessageType> types) {}
  @override
  void unsubscribe(String agentId) {}
  @override
  Stream<AgentMessage> streamFor(String agentId) => const Stream.empty();
}

AgentInput _agentInput({String command = 'decris'}) {
  return AgentInput(
    command: command,
    params: const {},
    source: InputSource.voice,
    timestamp: DateTime(2026, 1, 1),
  );
}

// --- Tests ---

void main() {
  late KitaDescribePlugin plugin;
  late MockSensorAccess mockSensors;
  late MockAIAccess mockAI;
  late MockOutputHandle mockOutput;
  late MockAgentBus mockBus;
  late FakeClock fakeClock;
  late List<LogEntry> logEntries;

  setUp(() {
    plugin = KitaDescribePlugin();
    mockSensors = MockSensorAccess();
    mockAI = MockAIAccess();
    mockOutput = MockOutputHandle(agentId: 'com.kita.describe');
    mockBus = MockAgentBus();
    fakeClock = FakeClock();
    logEntries = [];
    KitaLogger.testLogHandler = (entry) => logEntries.add(entry);
  });

  tearDown(() {
    KitaLogger.testLogHandler = null;
    mockOutput.dispose();
  });

  Future<void> spawnPlugin({MemoryAccess? memory}) async {
    final context = AgentContext(
      sensors: mockSensors,
      ai: mockAI,
      bus: mockBus,
      output: mockOutput,
      clock: fakeClock,
      memory: memory,
    );
    await plugin.onSpawn(context);
  }

  group('manifest', () {
    test('has correct id', () {
      expect(plugin.manifest.id, 'com.kita.describe');
    });

    test('has correct name', () {
      expect(plugin.manifest.name, 'Kita Describe');
    });

    test('has correct version', () {
      expect(plugin.manifest.version, '1.0.0');
    });

    test('declares camera, ai.vision and memory permissions', () {
      expect(plugin.manifest.permissions, ['camera', 'ai.vision', 'memory']);
    });

    test('has official trust level', () {
      expect(plugin.manifest.trustLevel, TrustLevel.official);
    });

    test('declares vision and text capabilities', () {
      expect(plugin.manifest.capabilities, containsAll(['vision', 'text']));
    });

    test('declares compatible profiles', () {
      expect(
        plugin.manifest.compatibleProfiles,
        containsAll(['blind', 'low_vision', 'standard']),
      );
    });

    test('is onDemand agent type', () {
      expect(plugin.manifest.agentType, AgentType.onDemand);
    });

    test('has standard priority', () {
      expect(plugin.manifest.priority, AgentPriority.standard);
    });
  });

  group('voiceCommands', () {
    test('has decris as primary trigger', () {
      expect(plugin.voiceCommands.first.trigger, 'decris');
    });

    test('has describe alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('describe'));
    });

    test('has decrit alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('decrit'));
    });

    test('has decrivez alias', () {
      expect(plugin.voiceCommands.first.aliases, contains('decrivez'));
    });

    test('has descriptive description', () {
      expect(
        plugin.voiceCommands.first.description,
        isNotEmpty,
      );
    });
  });

  group('handleInput', () {
    setUp(() async {
      await spawnPlugin();
    });

    test('returns text description on full success', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      final output = (result as Success<AgentOutput>).value;
      expect(output.type, AgentOutputType.text);
      expect(output.content, contains('salon'));
    });

    test('response metadata contains streaming flag', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());
      final output = (result as Success<AgentOutput>).value;

      expect(output.metadata, isNotNull);
      expect(output.metadata!['streaming'], isTrue);
    });

    test('sends describe prompt to AI vision stream', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      expect(mockAI.lastPromptReceived, KitaDescribePlugin.describePrompt);
    });

    test('returns failure on camera error', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result = await plugin.handleInput(_agentInput());

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect((failure as PluginFailure).pluginId, 'com.kita.describe');
    });

    test('returns failure on AI error', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const AIProviderFailure(
        userMessage: 'Service IA indisponible.',
        logMessage: 'AI vision timeout',
      );

      final result = await plugin.handleInput(_agentInput());

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
    });

    test('passes captured image directly to AI (EXIF stripped by sandbox)', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      final result = await plugin.handleInput(_agentInput());

      // Should succeed — plugin trusts the sandbox for privacy
      expect(result.isSuccess, isTrue);

      // The image sent to AI is exactly what the sensor returned
      // (EXIF stripping is now handled by SandboxedSensorAccess)
      expect(mockAI.lastImageReceived, same(mockSensors.photoToReturn));
    });

    test('logs each pipeline step', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Handling command')));
      expect(messages, contains(contains('Photo captured')));
      expect(messages, contains(contains('Streaming description complete')));
    });

    test('plugin logs contain [Plugin.Describe] source', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse();

      await plugin.handleInput(_agentInput());

      final pluginLogs = logEntries
          .where((e) => e.message.startsWith('[Plugin.Describe]'))
          .toList();
      expect(pluginLogs, isNotEmpty);
      expect(pluginLogs.length, greaterThanOrEqualTo(3));
    });

    test('camera failure userMessage is in French', () async {
      mockSensors.failureToReturn = PermissionFailure.denied('camera');

      final result = await plugin.handleInput(_agentInput());
      final failure = (result as Failure).failure;

      expect(failure.userMessage, 'Impossible de prendre la photo.');
    });

    test('AI failure userMessage is in French', () async {
      mockSensors.photoToReturn = testImage();
      mockAI.failureToReturn = const NetworkFailure(
        userMessage: 'Timeout',
        logMessage: 'AI request timed out',
      );

      final result = await plugin.handleInput(_agentInput());
      final failure = (result as Failure).failure;

      expect(failure.userMessage, "Je n'ai pas pu analyser l'image.");
    });
  });

  group('lifecycle', () {
    test('onSpawn completes without error', () async {
      await expectLater(spawnPlugin(), completes);
    });

    test('onTerminate completes without error', () async {
      await spawnPlugin();
      await expectLater(plugin.onTerminate(), completes);
    });

    test('onSpawn logs activation', () async {
      await spawnPlugin();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe agent spawned')));
    });

    test('onTerminate logs deactivation', () async {
      await spawnPlugin();
      await plugin.onTerminate();

      final messages = logEntries.map((e) => e.message).toList();
      expect(messages, contains(contains('Describe agent terminated')));
    });
  });

  group('buildViewport', () {
    testWidgets('returns null', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            final viewport = plugin.buildViewport(context);
            expect(viewport, isNull);
            return const SizedBox.shrink();
          },
        ),
      );
    });
  });

  group('prompt', () {
    test('est en français', () {
      expect(KitaDescribePlugin.describePrompt, contains('français'));
    });

    // Verrouille le correctif de latence : sans première phrase courte,
    // l'utilisateur attend ~25 s avant d'entendre le moindre mot.
    test('demande une première phrase très courte', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains('phrase très courte'),
      );
    });

    test('demande de situer les objets dans l\'espace', () {
      expect(KitaDescribePlugin.describePrompt, contains('gauche'));
      expect(KitaDescribePlugin.describePrompt, contains('droite'));
    });

    // Lire un panneau ou une étiquette est une fonction majeure pour un aveugle.
    test('demande de signaler le texte visible', () {
      expect(KitaDescribePlugin.describePrompt, contains('texte visible'));
    });

    test('interdit d\'identifier les personnes', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains("N'identifie jamais les personnes"),
      );
    });

    test('interdit les formules d\'introduction', () {
      expect(
        KitaDescribePlugin.describePrompt,
        contains("Ne mentionne pas que c'est une image"),
      );
    });

    test('reste bref (moins de 400 caractères)', () {
      expect(KitaDescribePlugin.describePrompt.length, lessThan(400));
    });
  });

  group('memory episodes', () {
    test('écrit un épisode après une description réussie', () async {
      final memory = FakeMemoryAccess();
      await spawnPlugin(memory: memory);
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn =
          testAIResponse(content: 'Un bureau. Une souris grise.');

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      expect(memory.savedEpisodes, hasLength(1));
      final episode = memory.savedEpisodes.single;
      expect(episode.source, equals('com.kita.describe'));
      expect(episode.eventType, equals('scene_description'));
      expect(episode.summary, equals('Un bureau.'));
      expect(episode.details, contains('souris grise'));
      expect(episode.isPinned, isFalse);
      expect(episode.importanceScore, equals(0.3));
      expect(episode.createdAt, equals(fakeClock.now()));
    });

    test("n'écrit rien et n'échoue pas quand la mémoire est indisponible",
        () async {
      await spawnPlugin();
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un bureau.');

      // context.memory est null (mémoire indisponible / pas de permission) :
      // `handleInput` ne doit jamais lever, la description doit aboutir.
      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
    });

    test(
        "la description aboutit même quand l'écriture de l'épisode échoue, "
        'et un avertissement est journalisé sans PII', () async {
      final memory = FakeMemoryAccess()
        ..saveEpisodeFailure = const PluginFailure(
          userMessage: 'La mémoire est indisponible.',
          logMessage: 'vault locked',
          pluginId: 'com.kita.describe',
        );
      await spawnPlugin(memory: memory);
      mockSensors.photoToReturn = testImage();
      const content = 'Un salon avec un canape secret jamais journalise.';
      mockAI.responseToReturn = testAIResponse(content: content);

      final result = await plugin.handleInput(_agentInput());

      // L'échec d'écriture de l'épisode ne doit JAMAIS faire échouer la
      // description : Marie a besoin d'entendre ce que voit la caméra,
      // la mémoire n'est qu'un bonus.
      expect(result.isSuccess, isTrue);
      expect(memory.savedEpisodes, isEmpty);

      final warnings = logEntries
          .where((e) => e.message.contains('Episode not saved'))
          .toList();
      expect(warnings, isNotEmpty);

      // Zero PII : le contenu de la description (ce que voit la caméra chez
      // l'utilisateur) ne doit jamais apparaître dans les logs, même en cas
      // d'échec d'écriture.
      for (final entry in logEntries) {
        expect(entry.message, isNot(contains(content)));
      }
    });

    test(
        "'decris' puis 'plus de details' n'ecrivent qu'un seul episode, "
        'celui de la description initiale', () async {
      final memory = FakeMemoryAccess();
      await spawnPlugin(memory: memory);
      mockSensors.photoToReturn = testImage();

      mockAI.responseToReturn =
          testAIResponse(content: 'Un bureau. Une souris grise.');
      final initial = await plugin.handleInput(_agentInput());
      expect(initial.isSuccess, isTrue);

      // Contenu different pour prouver que l'episode conserve est bien
      // celui de la description initiale, pas celui de l'approfondissement.
      mockAI.responseToReturn = testAIResponse(
          content: 'Le bureau a un tiroir entrouvert avec des cables.');
      final details =
          await plugin.handleInput(_agentInput(command: 'plus de details'));
      expect(details.isSuccess, isTrue);

      // « plus de details » redecrit la meme photo : un second episode
      // ferait begayer le rappel memoire ("qu'est-ce que j'ai vu ?").
      expect(memory.savedEpisodes, hasLength(1));
      expect(memory.savedEpisodes.single.summary, equals('Un bureau.'));
    });

    test(
        "'plus de details' seul, apres un 'decris' prealable, n'augmente "
        'pas le nombre d\'episodes enregistres', () async {
      final memory = FakeMemoryAccess();
      await spawnPlugin(memory: memory);
      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un bureau.');

      await plugin.handleInput(_agentInput());
      final countAfterInitial = memory.savedEpisodes.length;

      mockAI.responseToReturn =
          testAIResponse(content: 'Un bureau avec un ordinateur portable.');
      final details =
          await plugin.handleInput(_agentInput(command: 'plus de details'));

      expect(details.isSuccess, isTrue);
      expect(memory.savedEpisodes, hasLength(countAfterInitial));
    });
  });

  group('firstSentence', () {
    test('une phrase simple se termine au premier point', () {
      expect(
        KitaDescribePlugin.firstSentence('Un bureau. Une souris grise.'),
        equals('Un bureau.'),
      );
    });

    test('un texte sans ponctuation finale renvoie le texte entier', () {
      expect(
        KitaDescribePlugin.firstSentence('Un bureau sans ponctuation'),
        equals('Un bureau sans ponctuation'),
      );
    });

    test(
        'un texte commençant par une abréviation tronque tôt — limite '
        'connue de la détection naïve par ponctuation, documentée plutôt '
        'que corrigée (summary reste lisible pour des descriptions de '
        'scène)', () {
      expect(
        KitaDescribePlugin.firstSentence('M. Dupont attend dans le couloir.'),
        equals('M.'),
      );
    });

    test('une chaîne vide renvoie une chaîne vide', () {
      expect(KitaDescribePlugin.firstSentence(''), equals(''));
    });
  });

  group('memory chain end-to-end (base Drift réelle)', () {
    // Preuve bout-en-bout, avec une VRAIE base Drift en mémoire (pas de mock
    // DB) : KitaDescribePlugin -> VaultMemoryAccess -> MemoryVaultImpl ->
    // Drift (SQLite). Sans le consentement 'episodic' accordé via
    // MemoryConsent.ensureGranted, saveEpisode échouerait silencieusement et
    // ce test passerait pour la mauvaise raison.
    late KitaDatabase db;
    late MemoryVault vault;

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
        database: db,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
        "après une description réussie, l'épisode est réellement relisible "
        'via vault.getEpisodes() (pas seulement un Result de succès en '
        'façade)', () async {
      await MemoryConsent.ensureGranted(vault);

      final memory = VaultMemoryAccess(vaultLoader: () async => vault);
      final context = AgentContext(
        sensors: mockSensors,
        ai: mockAI,
        bus: mockBus,
        output: mockOutput,
        clock: fakeClock,
        memory: memory,
      );
      await plugin.onSpawn(context);

      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn =
          testAIResponse(content: 'Un bureau. Une souris grise.');

      final result = await plugin.handleInput(_agentInput());
      expect(result.isSuccess, isTrue);

      // Relecture directement depuis le vault réel : preuve que la donnée a
      // atteint la table Drift `episode`, pas seulement un mock du test.
      final stored = (await vault.getEpisodes()).getOrNull()!;
      expect(stored, hasLength(1));
      expect(stored.single.source, equals('com.kita.describe'));
      expect(stored.single.eventType, equals('scene_description'));
      expect(stored.single.summary, equals('Un bureau.'));
      expect(stored.single.details, contains('souris grise'));
    });

    test(
        "sans consentement, l'épisode n'est pas écrit — la description "
        'aboutit quand même', () async {
      // Pas de MemoryConsent.ensureGranted ici : la table `consent` reste
      // vide, donc MemoryVaultImpl.saveEpisode échoue.
      final memory = VaultMemoryAccess(vaultLoader: () async => vault);
      final context = AgentContext(
        sensors: mockSensors,
        ai: mockAI,
        bus: mockBus,
        output: mockOutput,
        clock: fakeClock,
        memory: memory,
      );
      await plugin.onSpawn(context);

      mockSensors.photoToReturn = testImage();
      mockAI.responseToReturn = testAIResponse(content: 'Un bureau.');

      final result = await plugin.handleInput(_agentInput());

      expect(result.isSuccess, isTrue);
      final stored = (await vault.getEpisodes()).getOrNull()!;
      expect(stored, isEmpty);
    });
  });
}
