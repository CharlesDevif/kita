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

  /// Describes what the camera sees.
  ///
  /// Triggers the DescribeAgent pipeline: capture photo, strip EXIF,
  /// send to AI vision, speak the result.
  static const describe = ToolSpec(
    name: 'describe',
    description:
        'Prend une photo avec la camera et decrit ce qui est visible. '
        "Utilise cet outil quand l'utilisateur demande de decrire son "
        "environnement, ce qu'il y a devant lui, autour de lui, ou ce "
        "que la camera voit. L'outil capture une photo, l'analyse par IA, "
        'et renvoie une description textuelle de la scene.',
    parameters: {
      'detail_level': ToolParameter(
        type: 'string',
        description:
            'Niveau de detail souhaite pour la description. '
            '"brief" pour 2-3 phrases, "detailed" pour 5-8 phrases.',
        enumValues: ['brief', 'detailed'],
      ),
    },
  );

  /// Activates or deactivates real-time obstacle surveillance.
  ///
  /// Triggers the AlertAgent to start or stop monitoring the camera
  /// feed for obstacles and dangers.
  static const alert = ToolSpec(
    name: 'alert',
    description:
        "Active ou desactive la surveillance d'obstacles en temps reel. "
        "Utilise cet outil quand l'utilisateur veut etre prevenu des "
        'obstacles, dangers ou changements dans son environnement. '
        "Le mode 'start' active la camera et la detection d'obstacles. "
        "Le mode 'stop' desactive la surveillance.",
    parameters: {
      'action': ToolParameter(
        type: 'string',
        description: 'Activer ou desactiver la surveillance.',
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
