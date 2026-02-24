import 'ai_access.dart';
import 'memory_access.dart';
import 'sensor_access.dart';

class PluginRequest {
  const PluginRequest({
    required this.command,
    this.params = const {},
    required this.sensors,
    required this.ai,
    this.memory,
  });

  final String command;
  final Map<String, dynamic> params;
  final SensorAccess sensors;
  final AIAccess ai;
  final MemoryAccess? memory;
}
