import 'package:flutter_test/flutter_test.dart';
import 'package:kita/features/orchestration/data/agent_bus_impl.dart';
import 'package:kita/features/orchestration/domain/models/agent_message.dart';

AgentMessage makeMessage({
  required AgentMessageType type,
  String fromAgent = 'system',
  String? toAgent,
  Map<String, dynamic> payload = const {},
}) {
  return AgentMessage(
    fromAgent: fromAgent,
    toAgent: toAgent,
    type: type,
    payload: payload,
    timestamp: DateTime(2026, 1, 1),
  );
}

void main() {
  late AgentBusImpl bus;

  setUp(() {
    bus = AgentBusImpl();
  });

  tearDown(() {
    bus.dispose();
  });

  group('AgentBusImpl', () {
    test('delivers message only to agent subscribed to that type', () async {
      bus.subscribe('alert', {AgentMessageType.detectionEvent});
      bus.subscribe('describe', {AgentMessageType.cancelAll});

      final alertMessages = <AgentMessage>[];
      final describeMessages = <AgentMessage>[];

      bus.streamFor('alert').listen(alertMessages.add);
      bus.streamFor('describe').listen(describeMessages.add);

      bus.publish(makeMessage(type: AgentMessageType.detectionEvent));

      // Allow the stream event to propagate.
      await Future.microtask(() {});

      expect(alertMessages, hasLength(1));
      expect(alertMessages.first.type, AgentMessageType.detectionEvent);
      expect(describeMessages, isEmpty);
    });

    test('delivers broadcast message to all subscribers of that type',
        () async {
      bus.subscribe('alert', {AgentMessageType.cancelAll});
      bus.subscribe('describe', {AgentMessageType.cancelAll});

      final alertMessages = <AgentMessage>[];
      final describeMessages = <AgentMessage>[];

      bus.streamFor('alert').listen(alertMessages.add);
      bus.streamFor('describe').listen(describeMessages.add);

      bus.publish(makeMessage(type: AgentMessageType.cancelAll));

      await Future.microtask(() {});

      expect(alertMessages, hasLength(1));
      expect(describeMessages, hasLength(1));
    });

    test('delivers targeted message only to the specified toAgent', () async {
      bus.subscribe('alert', {AgentMessageType.interruptRequest});
      bus.subscribe('describe', {AgentMessageType.interruptRequest});

      final alertMessages = <AgentMessage>[];
      final describeMessages = <AgentMessage>[];

      bus.streamFor('alert').listen(alertMessages.add);
      bus.streamFor('describe').listen(describeMessages.add);

      bus.publish(makeMessage(
        type: AgentMessageType.interruptRequest,
        toAgent: 'describe',
      ));

      await Future.microtask(() {});

      expect(alertMessages, isEmpty);
      expect(describeMessages, hasLength(1));
    });

    test('unsubscribed agent receives no more messages', () async {
      bus.subscribe('alert', {AgentMessageType.cancelAll});

      final messages = <AgentMessage>[];
      final subscription = bus.streamFor('alert').listen(messages.add);

      bus.publish(makeMessage(type: AgentMessageType.cancelAll));
      await Future.microtask(() {});
      expect(messages, hasLength(1));

      bus.unsubscribe('alert');

      bus.publish(makeMessage(type: AgentMessageType.cancelAll));
      await Future.microtask(() {});
      expect(messages, hasLength(1)); // No new messages after unsubscribe.

      await subscription.cancel();
    });

    test('agent not subscribed to a type does not receive messages of that type',
        () async {
      bus.subscribe('alert', {AgentMessageType.detectionEvent});

      final messages = <AgentMessage>[];
      bus.streamFor('alert').listen(messages.add);

      bus.publish(makeMessage(type: AgentMessageType.cancelAll));
      await Future.microtask(() {});

      expect(messages, isEmpty);
    });

    test('dispose closes the stream without error', () async {
      bus.subscribe('alert', {AgentMessageType.cancelAll});

      var streamDone = false;
      bus.streamFor('alert').listen(
        (_) {},
        onDone: () => streamDone = true,
      );

      bus.dispose();
      await Future.microtask(() {});

      expect(streamDone, isTrue);
    });

    test('publish after dispose does not throw', () {
      bus.dispose();

      // Should not throw even after dispose.
      expect(
        () => bus.publish(makeMessage(type: AgentMessageType.cancelAll)),
        returnsNormally,
      );
    });

    test('targeted message not delivered if toAgent is not subscribed to type',
        () async {
      bus.subscribe('describe', {AgentMessageType.cancelAll});

      final messages = <AgentMessage>[];
      bus.streamFor('describe').listen(messages.add);

      // Send interruptRequest to describe, but describe is only subscribed
      // to cancelAll.
      bus.publish(makeMessage(
        type: AgentMessageType.interruptRequest,
        toAgent: 'describe',
      ));

      await Future.microtask(() {});
      expect(messages, isEmpty);
    });
  });
}
