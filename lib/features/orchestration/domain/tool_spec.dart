/// Specification for a tool that the conversational LLM can call.
///
/// Each [ToolSpec] maps to one action Kita can perform (e.g., describe a
/// scene, start obstacle alerts). The spec is converted to the native
/// tool/function-calling format of each provider:
///
/// - **Claude**: `tools` array with `input_schema` (JSON Schema)
/// - **OpenAI**: `tools` array with `function.parameters` (JSON Schema)
/// - **Gemma/local**: plain-text tool description injected into the prompt
///
/// ## Design notes
///
/// Tool descriptions should be detailed and in French (matching KitaSoul),
/// because the LLM uses the description to decide when to call the tool.
/// See Claude docs: "provide extremely detailed descriptions" for best
/// tool-use performance.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  /// Machine-readable tool name (e.g., "describe", "alert").
  /// Must be a valid identifier: lowercase, no spaces, [a-z0-9_].
  final String name;

  /// Detailed description of what this tool does and when to use it.
  /// Written in French to match the system prompt language.
  final String description;

  /// Parameters the LLM can pass when calling this tool.
  /// Keys are parameter names, values are [ToolParameter] specs.
  final Map<String, ToolParameter> parameters;

  /// Converts to Claude API tool format.
  ///
  /// ```json
  /// {
  ///   "name": "describe",
  ///   "description": "...",
  ///   "input_schema": {
  ///     "type": "object",
  ///     "properties": { ... },
  ///     "required": [ ... ]
  ///   }
  /// }
  /// ```
  Map<String, dynamic> toClaudeFormat() {
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final entry in parameters.entries) {
      properties[entry.key] = entry.value._toJsonSchema();
      if (entry.value.isRequired) {
        required.add(entry.key);
      }
    }

    return {
      'name': name,
      'description': description,
      'input_schema': {
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
      },
    };
  }

  /// Converts to OpenAI function-calling format.
  ///
  /// ```json
  /// {
  ///   "type": "function",
  ///   "function": {
  ///     "name": "describe",
  ///     "description": "...",
  ///     "parameters": {
  ///       "type": "object",
  ///       "properties": { ... },
  ///       "required": [ ... ]
  ///     }
  ///   }
  /// }
  /// ```
  Map<String, dynamic> toOpenAIFormat() {
    final properties = <String, dynamic>{};
    final required = <String>[];

    for (final entry in parameters.entries) {
      properties[entry.key] = entry.value._toJsonSchema();
      if (entry.value.isRequired) {
        required.add(entry.key);
      }
    }

    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      },
    };
  }

  /// Converts to a plain-text prompt description for local models
  /// (Gemma, TFLite) that don't support native function calling.
  ///
  /// The format is designed so the LLM outputs a parseable call string
  /// like `<tool_call>{"name":"describe","arguments":{}}</tool_call>`.
  String toGemmaPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('Outil "$name": $description');

    if (parameters.isNotEmpty) {
      buffer.writeln('  Paramètres:');
      for (final entry in parameters.entries) {
        final param = entry.value;
        final req = param.isRequired ? ' (obligatoire)' : ' (optionnel)';
        buffer.write('  - ${entry.key} (${param.type})$req: ${param.description}');
        if (param.enumValues != null && param.enumValues!.isNotEmpty) {
          buffer.write(' [${param.enumValues!.join(", ")}]');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}

/// Specification for a single parameter of a [ToolSpec].
class ToolParameter {
  const ToolParameter({
    required this.type,
    required this.description,
    this.isRequired = false,
    this.enumValues,
  });

  /// JSON Schema type: "string", "number", "integer", "boolean".
  final String type;

  /// Human-readable description of this parameter (in French).
  final String description;

  /// Whether the LLM must provide this parameter.
  final bool isRequired;

  /// Allowed values when [type] is "string" and the parameter is an enum.
  final List<String>? enumValues;

  /// Converts to a JSON Schema property definition.
  Map<String, dynamic> _toJsonSchema() {
    return {
      'type': type,
      'description': description,
      if (enumValues != null && enumValues!.isNotEmpty) 'enum': enumValues,
    };
  }
}
