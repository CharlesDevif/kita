import 'memory_domain.dart';

enum ForgetScope { everything, domain, olderThan, specific }

class ForgetRequest {
  const ForgetRequest({
    required this.scope,
    this.domain,
    this.before,
    required this.confirmation,
    this.specificIds = const [],
  });

  final ForgetScope scope;
  final MemoryDomain? domain;
  final DateTime? before;
  final bool confirmation;
  final List<String> specificIds;
}
