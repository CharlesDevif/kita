import 'memory_domain.dart';

enum ForgetScope { everything, domain, plugin, olderThan, specific }

class ForgetRequest {
  const ForgetRequest({
    required this.scope,
    this.domain,
    this.pluginId,
    this.before,
    required this.confirmation,
    this.specificIds = const [],
  });

  factory ForgetRequest.everything({required bool confirmation}) =>
      ForgetRequest(scope: ForgetScope.everything, confirmation: confirmation);

  factory ForgetRequest.domain(
    MemoryDomain domain, {
    required bool confirmation,
  }) =>
      ForgetRequest(
        scope: ForgetScope.domain,
        domain: domain,
        confirmation: confirmation,
      );

  factory ForgetRequest.plugin(
    String pluginId, {
    required bool confirmation,
  }) =>
      ForgetRequest(
        scope: ForgetScope.plugin,
        pluginId: pluginId,
        confirmation: confirmation,
      );

  factory ForgetRequest.olderThan(
    DateTime before, {
    required bool confirmation,
  }) =>
      ForgetRequest(
        scope: ForgetScope.olderThan,
        before: before,
        confirmation: confirmation,
      );

  factory ForgetRequest.specific(
    List<String> ids, {
    required bool confirmation,
  }) =>
      ForgetRequest(
        scope: ForgetScope.specific,
        specificIds: ids,
        confirmation: confirmation,
      );

  final ForgetScope scope;
  final MemoryDomain? domain;
  final String? pluginId;
  final DateTime? before;
  final bool confirmation;
  final List<String> specificIds;
}
