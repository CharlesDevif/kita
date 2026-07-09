import '../domain/tool_spec.dart';

/// Registry of tools available to Kita's conversational LLM.
///
/// Each tool maps to a capability in the agent system. When the LLM
/// decides to call a tool, the [ConversationEngine] routes the call
/// to the appropriate agent via the [InputRouter].
///
/// ## Adding a new tool
///
/// 1. Define a `static const ToolSpec` here with a detailed French description.
/// 2. Add it to the [all] list.
/// 3. Handle the tool name in [ConversationEngine._executeToolCall].
/// 4. (Optional) Map it to a [VoiceCommand] if it should also be
///    triggered by direct voice commands.
class KitaTools {
  KitaTools._();

  /// Tool name constants — used in switch statements and tool dispatch.
  static const toolDescribe = 'describe';
  static const toolAlert = 'alert';

  /// Outils dont l'agent délivre lui-même le résultat à voix haute.
  /// Après leur exécution, la boucle tool-use s'arrête : renvoyer le
  /// résultat au LLM pour une « conclusion » serait redondant à l'oreille
  /// et faisait expirer le timeout local pendant que la vision occupe le
  /// moteur (fausse alerte vocalisée — observé sur device).
  static const Set<String> selfSpeakingTools = {toolDescribe, toolAlert};

  /// Command constant sent to agents when routing voice input.
  /// Must match DescribePlugin.handleInput's switch case ('decris').
  static const commandDescribe = 'decris';

  /// Describes what the camera sees.
  ///
  /// Triggers the DescribeAgent pipeline: capture photo, strip EXIF,
  /// send to AI vision, speak the result.
  static const describe = ToolSpec(
    name: toolDescribe,
    description:
        'Prend une photo et décrit ce que la caméra voit. À utiliser quand '
        "l'utilisateur veut savoir ce qu'il y a autour de lui.",
  );

  /// Activates or deactivates real-time obstacle surveillance.
  ///
  /// Triggers the AlertAgent to start or stop monitoring the camera
  /// feed for obstacles and dangers.
  static const alert = ToolSpec(
    name: toolAlert,
    description:
        "Active ('start') ou désactive ('stop') la surveillance d'obstacles "
        'en temps réel.',
    parameters: {
      'action': ToolParameter(
        type: 'string',
        description:
            "Action à effectuer. 'start' active la surveillance "
            "d'obstacles en continu. 'stop' arrête la surveillance.",
        isRequired: true,
        enumValues: ['start', 'stop'],
      ),
    },
  );

  /// All tools available to the conversational LLM.
  ///
  /// This list is used by the AI provider adapters to build the
  /// tool/function definitions in each provider's native format.
  static List<ToolSpec> get all => const [describe, alert];
}
