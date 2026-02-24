import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kita/core/errors/kita_failure.dart';
import 'package:kita/core/errors/result.dart';
import 'package:kita/features/plugins/data/plugin_registry.dart';
import 'package:kita/features/plugins/domain/kita_plugin.dart';
import 'package:kita/features/plugins/domain/plugin_manifest.dart';
import 'package:kita/features/plugins/domain/plugin_request.dart';
import 'package:kita/features/plugins/domain/plugin_response.dart';
import 'package:kita/features/plugins/domain/plugin_state.dart';
import 'package:kita/features/plugins/domain/trust_level.dart';
import 'package:kita/features/plugins/domain/voice_command.dart';

// --- Test Double ---

class FakePlugin implements KitaPlugin {
  FakePlugin({
    required this.manifest,
    this.commands = const [],
    this.throwOnActivate = false,
    this.throwOnDeactivate = false,
  });

  @override
  final PluginManifest manifest;

  final List<VoiceCommand> commands;
  final bool throwOnActivate;
  final bool throwOnDeactivate;

  bool activated = false;
  bool deactivated = false;

  @override
  List<VoiceCommand> get voiceCommands => commands;

  @override
  Future<void> onActivate() async {
    if (throwOnActivate) throw StateError('Activation failed');
    activated = true;
  }

  @override
  Future<void> onDeactivate() async {
    if (throwOnDeactivate) throw StateError('Deactivation failed');
    deactivated = true;
  }

  @override
  Future<Result<PluginResponse>> handleRequest(PluginRequest request) async {
    return const Result.success(PluginResponse(
      type: PluginResponseType.text,
      content: 'result',
    ));
  }

  @override
  Widget? buildViewport(BuildContext context) => null;
}

PluginManifest _manifest({
  String id = 'com.kita.test',
  String name = 'Test Plugin',
}) {
  return PluginManifest(
    id: id,
    name: name,
    version: '1.0.0',
    description: 'A test plugin',
    trustLevel: TrustLevel.official,
  );
}

void main() {
  late PluginRegistryImpl registry;

  setUp(() {
    registry = PluginRegistryImpl(maxActivePlugins: 3);
  });

  group('register', () {
    test('registers a plugin successfully', () {
      final plugin = FakePlugin(manifest: _manifest());
      final result = registry.register(plugin);

      expect(result.isSuccess, isTrue);
      expect(registry.listPlugins(), hasLength(1));
      expect(registry.listPlugins().first.state, equals(PluginState.registered));
    });

    test('fails to register duplicate plugin', () {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);

      final result = registry.register(plugin);
      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.logMessage, contains('already registered'));
    });

    test('registers multiple distinct plugins', () {
      registry.register(FakePlugin(manifest: _manifest(id: 'com.kita.one')));
      registry.register(FakePlugin(manifest: _manifest(id: 'com.kita.two')));
      registry.register(FakePlugin(manifest: _manifest(id: 'com.kita.three')));

      expect(registry.listPlugins(), hasLength(3));
    });
  });

  group('activate', () {
    test('activates a registered plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);

      final result = await registry.activate('com.kita.test');

      expect(result.isSuccess, isTrue);
      expect(plugin.activated, isTrue);
      expect(
        registry.listPlugins().first.state,
        equals(PluginState.active),
      );
    });

    test('fails to activate unregistered plugin', () async {
      final result = await registry.activate('com.kita.nonexistent');

      expect(result.isFailure, isTrue);
      expect((result as Failure).failure.logMessage, contains('not registered'));
    });

    test('no-ops when activating already active plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);
      await registry.activate('com.kita.test');

      final result = await registry.activate('com.kita.test');
      expect(result.isSuccess, isTrue);
    });

    test('fails when max active plugins reached', () async {
      for (var i = 0; i < 3; i++) {
        final plugin = FakePlugin(manifest: _manifest(id: 'com.kita.p$i'));
        registry.register(plugin);
        await registry.activate('com.kita.p$i');
      }

      final extra = FakePlugin(manifest: _manifest(id: 'com.kita.extra'));
      registry.register(extra);

      final result = await registry.activate('com.kita.extra');
      expect(result.isFailure, isTrue);
      expect((result as Failure).failure.logMessage, contains('Max active'));
    });

    test('handles plugin crash during activation', () async {
      final plugin = FakePlugin(
        manifest: _manifest(),
        throwOnActivate: true,
      );
      registry.register(plugin);

      final result = await registry.activate('com.kita.test');

      expect(result.isFailure, isTrue);
      final failure = (result as Failure).failure;
      expect(failure, isA<PluginFailure>());
      expect(failure.logMessage, contains('crashed during activation'));
      // Plugin should remain in registered state (not active)
      expect(
        registry.listPlugins().first.state,
        equals(PluginState.registered),
      );
    });

    test('re-activates an inactive plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);
      await registry.activate('com.kita.test');
      await registry.deactivate('com.kita.test');

      final result = await registry.activate('com.kita.test');
      expect(result.isSuccess, isTrue);
      expect(
        registry.listPlugins().first.state,
        equals(PluginState.active),
      );
    });
  });

  group('deactivate', () {
    test('deactivates an active plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);
      await registry.activate('com.kita.test');

      final result = await registry.deactivate('com.kita.test');

      expect(result.isSuccess, isTrue);
      expect(plugin.deactivated, isTrue);
      expect(
        registry.listPlugins().first.state,
        equals(PluginState.inactive),
      );
    });

    test('fails to deactivate unregistered plugin', () async {
      final result = await registry.deactivate('com.kita.nonexistent');

      expect(result.isFailure, isTrue);
    });

    test('no-ops when deactivating non-active plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);

      final result = await registry.deactivate('com.kita.test');
      expect(result.isSuccess, isTrue);
      expect(plugin.deactivated, isFalse); // onDeactivate not called
    });

    test('still marks inactive even if deactivation crashes', () async {
      final plugin = FakePlugin(
        manifest: _manifest(),
        throwOnDeactivate: true,
      );
      registry.register(plugin);
      await registry.activate('com.kita.test');

      final result = await registry.deactivate('com.kita.test');

      // Should still succeed (crash isolated)
      expect(result.isSuccess, isTrue);
      expect(
        registry.listPlugins().first.state,
        equals(PluginState.inactive),
      );
    });
  });

  group('getPlugin', () {
    test('returns active plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);
      await registry.activate('com.kita.test');

      expect(registry.getPlugin('com.kita.test'), equals(plugin));
    });

    test('returns null for registered but not active plugin', () {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);

      expect(registry.getPlugin('com.kita.test'), isNull);
    });

    test('returns null for inactive plugin', () async {
      final plugin = FakePlugin(manifest: _manifest());
      registry.register(plugin);
      await registry.activate('com.kita.test');
      await registry.deactivate('com.kita.test');

      expect(registry.getPlugin('com.kita.test'), isNull);
    });

    test('returns null for unknown plugin', () {
      expect(registry.getPlugin('com.kita.nonexistent'), isNull);
    });
  });

  group('listPlugins', () {
    test('returns empty list initially', () {
      expect(registry.listPlugins(), isEmpty);
    });

    test('returns all plugins with their states', () async {
      registry.register(
          FakePlugin(manifest: _manifest(id: 'com.kita.one', name: 'One')));
      registry.register(
          FakePlugin(manifest: _manifest(id: 'com.kita.two', name: 'Two')));
      registry.register(
          FakePlugin(manifest: _manifest(id: 'com.kita.three', name: 'Three')));

      await registry.activate('com.kita.one');
      await registry.activate('com.kita.two');
      await registry.deactivate('com.kita.two');

      final plugins = registry.listPlugins();
      expect(plugins, hasLength(3));

      final states = {for (final p in plugins) p.id: p.state};
      expect(states['com.kita.one'], equals(PluginState.active));
      expect(states['com.kita.two'], equals(PluginState.inactive));
      expect(states['com.kita.three'], equals(PluginState.registered));
    });

    test('returns unmodifiable list', () {
      registry.register(FakePlugin(manifest: _manifest()));
      final list = registry.listPlugins();

      expect(() => list.add(PluginEntry(
        plugin: FakePlugin(manifest: _manifest(id: 'com.kita.hack')),
        state: PluginState.active,
      )), throwsUnsupportedError);
    });
  });

  group('aggregatedVoiceCommands', () {
    test('returns empty when no active plugins', () {
      expect(registry.aggregatedVoiceCommands, isEmpty);
    });

    test('aggregates commands from active plugins only', () async {
      final describePlugin = FakePlugin(
        manifest: _manifest(id: 'com.kita.describe', name: 'Describe'),
        commands: const [
          VoiceCommand(trigger: 'decris', description: 'Describe'),
          VoiceCommand(trigger: 'describe', description: 'Describe EN'),
        ],
      );
      final alertPlugin = FakePlugin(
        manifest: _manifest(id: 'com.kita.alert', name: 'Alert'),
        commands: const [
          VoiceCommand(trigger: 'alerte', description: 'Alert'),
        ],
      );
      final inactivePlugin = FakePlugin(
        manifest: _manifest(id: 'com.kita.inactive', name: 'Inactive'),
        commands: const [
          VoiceCommand(trigger: 'hidden', description: 'Should not appear'),
        ],
      );

      registry.register(describePlugin);
      registry.register(alertPlugin);
      registry.register(inactivePlugin);

      await registry.activate('com.kita.describe');
      await registry.activate('com.kita.alert');
      // inactivePlugin stays registered, not activated

      final commands = registry.aggregatedVoiceCommands;
      expect(commands, hasLength(3));
      expect(commands.map((c) => c.trigger), containsAll(['decris', 'describe', 'alerte']));
      expect(commands.map((c) => c.trigger), isNot(contains('hidden')));
    });

    test('updates when plugin is deactivated', () async {
      final plugin = FakePlugin(
        manifest: _manifest(),
        commands: const [
          VoiceCommand(trigger: 'test', description: 'Test'),
        ],
      );
      registry.register(plugin);
      await registry.activate('com.kita.test');

      expect(registry.aggregatedVoiceCommands, hasLength(1));

      await registry.deactivate('com.kita.test');
      expect(registry.aggregatedVoiceCommands, isEmpty);
    });
  });

  group('integration: full lifecycle', () {
    test('register -> activate -> use -> deactivate', () async {
      final plugin = FakePlugin(
        manifest: _manifest(),
        commands: const [
          VoiceCommand(trigger: 'test', description: 'Test command'),
        ],
      );

      // Register
      expect(registry.register(plugin).isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.test'), isNull); // not active yet

      // Activate
      expect((await registry.activate('com.kita.test')).isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.test'), equals(plugin));
      expect(registry.aggregatedVoiceCommands, hasLength(1));

      // Use (getPlugin returns it)
      final active = registry.getPlugin('com.kita.test');
      expect(active, isNotNull);

      // Deactivate
      expect((await registry.deactivate('com.kita.test')).isSuccess, isTrue);
      expect(registry.getPlugin('com.kita.test'), isNull);
      expect(registry.aggregatedVoiceCommands, isEmpty);

      // Still listed as inactive
      final entry =
          registry.listPlugins().firstWhere((e) => e.id == 'com.kita.test');
      expect(entry.state, equals(PluginState.inactive));
    });

    test('crash in one plugin does not affect others', () async {
      final goodPlugin = FakePlugin(
        manifest: _manifest(id: 'com.kita.good'),
      );
      final crashingPlugin = FakePlugin(
        manifest: _manifest(id: 'com.kita.crash'),
        throwOnActivate: true,
      );

      registry.register(goodPlugin);
      registry.register(crashingPlugin);

      // Activate good plugin first
      expect((await registry.activate('com.kita.good')).isSuccess, isTrue);

      // Crashing plugin fails activation
      expect((await registry.activate('com.kita.crash')).isFailure, isTrue);

      // Good plugin is still active and unaffected
      expect(registry.getPlugin('com.kita.good'), equals(goodPlugin));
      expect(
        registry.listPlugins().firstWhere((e) => e.id == 'com.kita.good').state,
        equals(PluginState.active),
      );
    });

    test('deactivating frees slot for new activation', () async {
      // Fill max capacity (3)
      for (var i = 0; i < 3; i++) {
        registry.register(FakePlugin(manifest: _manifest(id: 'com.kita.p$i')));
        await registry.activate('com.kita.p$i');
      }

      // Cannot activate a 4th
      registry.register(FakePlugin(manifest: _manifest(id: 'com.kita.p3')));
      expect((await registry.activate('com.kita.p3')).isFailure, isTrue);

      // Deactivate one
      await registry.deactivate('com.kita.p0');

      // Now activation should succeed
      expect((await registry.activate('com.kita.p3')).isSuccess, isTrue);
    });
  });
}
