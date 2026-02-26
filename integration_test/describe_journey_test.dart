/// Journey test : "Décris" → description vocale en < 5s (AC2)
///
/// Valide le parcours :
///   commande vocale "décris" → spawn DescribeAgent → capture photo (mock)
///   → IA vision → description → TTS → épisode sauvegardé (Drift réel)
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kita/core/data/database.dart' hide UserProfile;
import 'package:kita/features/memory/domain/episode.dart';
import 'package:kita/features/memory/data/daos/consent_dao.dart';
import 'package:kita/features/memory/data/daos/episode_dao.dart';
import 'package:kita/features/memory/data/daos/person_dao.dart';
import 'package:kita/features/memory/data/daos/plugin_data_dao.dart';
import 'package:kita/features/memory/data/daos/preference_dao.dart';
import 'package:kita/features/memory/data/daos/profile_dao.dart';
import 'package:kita/features/memory/data/memory_vault_impl.dart';
import 'package:kita/features/memory/domain/memory_domain.dart';
import 'package:kita/features/orchestration/data/stub_access.dart';
import 'package:kita/features/orchestration/domain/models/raw_input.dart';
import 'package:kita/features/plugins/data/plugin_sandbox_impl.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/test_app.dart';

// =============================================================================
// Tests journey "décris"
// =============================================================================
// TODO(MEDIUM-1): Refactor to use OrchestratorTestHarness from test_app.dart
// to eliminate setup duplication with alert_journey_test.dart.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AgentBusImpl bus;
  late PluginSandboxImpl sandbox;
  late FakeClock clock;
  late IntegrationMockTTSService tts;
  late IntegrationMockHapticService haptic;
  late AgentSupervisor supervisor;
  late OutputCoordinator coordinator;
  late InputRouter inputRouter;
  late KitaOrchestrator orchestrator;
  late List<OrbState> orbStates;
  late List<ShellMode> shellModes;

  setUp(() {
    bus = AgentBusImpl();
    sandbox = PluginSandboxImpl(
      sensorAccess: StubSensorAccess(),
      aiAccess: StubAIAccess(),
    );
    clock = FakeClock();
    tts = IntegrationMockTTSService();
    haptic = IntegrationMockHapticService();
    orbStates = [];
    shellModes = [];

    coordinator = OutputCoordinator(
      tts: tts,
      haptic: haptic,
      profileAdapter: IntegrationMockProfileAdapter(),
      clock: clock,
      bus: bus,
      onOrbStateChanged: orbStates.add,
      onShellModeChanged: shellModes.add,
    );
    supervisor = AgentSupervisor(
      bus: bus,
      sandbox: sandbox,
      clock: clock,
      ttsService: tts,
      hapticService: haptic,
      outputCoordinator: coordinator,
    );
    inputRouter = InputRouter(
      supervisor: supervisor,
      outputCoordinator: coordinator,
      clock: clock,
    );
    orchestrator = KitaOrchestrator(
      inputRouter: inputRouter,
      supervisor: supervisor,
      outputCoordinator: coordinator,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    tts.dispose();
    await supervisor.dispose();
    bus.dispose();
  });

  // NOTE : Ce journey teste l'orchestration (DescribeAgent spawné) et la persistence
  // (épisode sauvegardé en DB Drift réelle) séparément. Le pipeline E2E complet
  // (capture photo → IA vision → description vocale) nécessiterait des mocks UI
  // complexes (camera, ML inference) hors scope de ce journey test.
  group('Journey "décris" — description vocale (AC2)', () {
    test(
      'commande "décris" → DescribeAgent spawné → résultat traité',
      () async {
        final stopwatch = Stopwatch()..start();

        await orchestrator.initialize();
        await orchestrator.handleInput(RawInput.voice('decris', clock: clock));

        stopwatch.stop();

        // DescribeAgent doit être spawné
        expect(
          supervisor.agents.containsKey('com.kita.describe'),
          isTrue,
          reason: 'DescribeAgent doit être spawné par la commande "décris"',
        );

        // Le flow complet doit rester dans l'ordre de grandeur attendu (< 5s)
        expect(
          stopwatch.elapsed.inSeconds,
          lessThan(5),
          reason: 'Journey "décris" doit compléter en < 5s wall-clock',
        );

        // AC2 : vérifier que le TTS a bien été sollicité (description vocale)
        // Avec StubAIAccess, la description peut être dégradée mais le TTS
        // doit tout de même recevoir au moins un texte à prononcer.
        expect(
          tts.spokenTexts,
          isNotEmpty,
          reason: 'Le TTS doit avoir reçu au moins un texte à prononcer '
              'lors du journey "décris" (AC2 — description vocale)',
        );
      },
    );

    test(
      'AlertAgent persiste pendant le journey décris',
      () async {
        await orchestrator.initialize();

        // AlertAgent démarré à l'initialisation (persistent)
        expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);

        // Envoyer commande décris
        await orchestrator.handleInput(RawInput.voice('decris', clock: clock));

        // AlertAgent doit toujours être actif
        expect(supervisor.agents.containsKey('com.kita.alert'), isTrue);
        expect(supervisor.agents.length, greaterThanOrEqualTo(1));
      },
    );

    test(
      'fallback hors-ligne : orchestrateur ne crashe pas sans cloud',
      () async {
        // Avec StubAIAccess, l'accès cloud n'est pas disponible.
        // L'orchestrateur doit gérer l'erreur gracieusement.
        await orchestrator.initialize();

        // Ne doit pas lancer d'exception
        await expectLater(
          orchestrator.handleInput(RawInput.voice('decris', clock: clock)),
          completes,
          reason: 'handleInput ne doit jamais lancer d\'exception',
        );
      },
    );

    test(
      'épisode sauvegardé en mémoire Drift réelle (in-memory DB)',
      () async {
        // Test avec DB Drift réelle (pas de mock) — pattern phase2_gate
        final rawDb = sql.sqlite3.openInMemory();
        final db = KitaDatabase(NativeDatabase.opened(rawDb));
        final consentDao = ConsentDao(db);
        final episodeDao = EpisodeDao(db);
        final vault = MemoryVaultImpl(
          episodeDao: episodeDao,
          preferenceDao: PreferenceDao(db),
          personDao: PersonDao(db),
          profileDao: ProfileDao(db),
          pluginDataDao: PluginDataDao(db),
          consentDao: consentDao,
        );

        try {
          // Accorder le consentement data_storage
          await consentDao.insert(
            consentType: 'data_storage',
            scope: 'episodic',
            granted: true,
          );

          // Simuler la sauvegarde d'un épisode résultant d'une description
          final episode = KitaEpisode(
            id: 0,
            source: 'describe_agent',
            eventType: 'description',
            summary: 'Un salon avec un canapé rouge',
            details: 'Photo prise lors du journey describe integration test',
            tags: ['intérieur', 'canapé'],
            importanceScore: 0.8,
            isPinned: false,
            createdAt: DateTime.now(),
          );

          final saveResult = await vault.saveEpisode(episode);
          expect(saveResult.isSuccess, isTrue);

          // Vérifier que l'épisode est récupérable
          final knowResult = await vault.whatDoYouKnow();
          expect(knowResult.isSuccess, isTrue);
          knowResult.when(
            success: (data) {
              expect(data.containsKey(MemoryDomain.episodic), isTrue);
              expect(data[MemoryDomain.episodic]!.isNotEmpty, isTrue);
              expect(
                data[MemoryDomain.episodic]!.any((s) => s.contains('canapé')),
                isTrue,
                reason: 'L\'épisode décrit doit être retrouvable en mémoire',
              );
            },
            failure: (f) => fail('whatDoYouKnow failed: ${f.logMessage}'),
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
