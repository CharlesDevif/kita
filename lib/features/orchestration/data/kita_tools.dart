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
        'Prend une photo avec la caméra et décrit ce qui est visible. '
        "Utilise cet outil quand l'utilisateur demande de décrire son "
        "environnement, ce qu'il y a devant lui, autour de lui, ou ce "
        "que la caméra voit. L'outil capture une photo, l'analyse par IA "
        'de vision, et renvoie une description textuelle de la scène '
        'organisée spatialement (gauche, droite, devant, derrière). '
        "N'utilise PAS cet outil pour lire du texte ou des documents. "
        'Si la caméra est indisponible, signale-le à l\'utilisateur.',
    parameters: {
      'detail_level': ToolParameter(
        type: 'string',
        description:
            'Niveau de détail souhaité pour la description. '
            '"brief" donne un résumé en 2-3 phrases des éléments principaux. '
            '"detailed" donne une description complète en 5-8 phrases avec '
            'les objets, personnes, couleurs et distances. Par défaut : "brief".',
        enumValues: ['brief', 'detailed'],
      ),
    },
  );

  /// Activates or deactivates real-time obstacle surveillance.
  ///
  /// Triggers the AlertAgent to start or stop monitoring the camera
  /// feed for obstacles and dangers.
  static const alert = ToolSpec(
    name: toolAlert,
    description:
        "Active ou désactive la surveillance d'obstacles en temps réel. "
        "Utilise cet outil quand l'utilisateur veut être prévenu des "
        'obstacles, dangers ou changements dans son environnement. '
        "Le mode 'start' active la caméra et la détection continue "
        "d'obstacles par IA de vision (personnes, objets, véhicules, "
        'escaliers, trottoirs). Quand un obstacle est détecté, '
        "l'utilisateur est alerté par retour audio et haptique. "
        "Le mode 'stop' désactive la surveillance et libère la caméra. "
        'Nécessite que la caméra soit accessible.',
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
