class VoiceCommand {
  const VoiceCommand({
    required this.trigger,
    required this.description,
    this.aliases = const [],
  });

  final String trigger;
  final String description;
  final List<String> aliases;
}
