import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_app/features/safety_device/domain/models.dart';
import 'package:wsa_app/features/safety_device/domain/ports.dart';
import 'package:wsa_app/features/safety_device/domain/safety_config.dart';
import 'package:wsa_app/features/safety_device/application/confirmation_gate.dart';

class PendingConfirmation implements ConfirmationBridge {
  final answer = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> requestConfirmation(SafetyTrigger trigger, Duration duration) {
    calls++;
    return answer.future;
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 13);
  test('GPS failure preserves a serializable SOS and its original ID', () {
    final event = EmergencyEvent(
      eventId: 'test-event',
      ownerId: 'test-user',
      createdAt: now,
      kind: EventKind.sos,
      trigger: TriggerType.manual,
      locationFailure: LocationFailure.timeout,
    );
    final restored = EmergencyEvent.fromJson(
      jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
    );
    expect(restored.eventId, event.eventId);
    expect(restored.location, isNull);
    expect(restored.locationFailure, LocationFailure.timeout);
    expect(restored.isEmergency, isTrue);
    expect(restored.createdAtUtc.isUtc, isTrue);
  });
  test('battery pre-alert cannot masquerade as an SOS trigger', () {
    final event = EmergencyEvent(
      eventId: 'battery',
      ownerId: 'test-user',
      createdAt: now,
      kind: EventKind.batteryPreAlert,
      batteryPercent: 10,
    );
    expect(event.isEmergency, isFalse);
    expect(
      () => EmergencyEvent(
        eventId: 'bad',
        ownerId: 'test-user',
        createdAt: now,
        kind: EventKind.batteryPreAlert,
        trigger: TriggerType.manual,
      ),
      throwsArgumentError,
    );
  });
  test('rejects invalid coordinates and stale or future cache', () {
    expect(
      () => LocationSnapshot(
        latitude: double.nan,
        longitude: 0,
        accuracyMeters: 5,
        capturedAt: now,
        source: LocationSource.current,
      ),
      throwsArgumentError,
    );
    final snapshot = LocationSnapshot(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 5,
      capturedAt: now,
      source: LocationSource.cached,
    );
    expect(
      snapshot.isFreshAt(
        now.add(const Duration(minutes: 1)),
        const Duration(minutes: 2),
      ),
      isTrue,
    );
    expect(
      snapshot.isFreshAt(
        now.add(const Duration(minutes: 3)),
        const Duration(minutes: 2),
      ),
      isFalse,
    );
    expect(
      snapshot.isFreshAt(
        now.subtract(const Duration(seconds: 1)),
        const Duration(minutes: 2),
      ),
      isFalse,
    );
  });
  test('invalid retry and threshold configuration is rejected', () {
    expect(() => const SafetyConfig().validate(), returnsNormally);
    expect(
      () => const SafetyConfig(maximumAutomaticAttempts: 0).validate(),
      throwsArgumentError,
    );
    expect(
      () => const SafetyConfig(batteryPreAlertThreshold: 30).validate(),
      throwsArgumentError,
    );
  });
  test('concurrent sensor triggers open one confirmation and cancellation releases it', () async {
    final bridge = PendingConfirmation();
    final gate = ConfirmationGate(bridge, const SafetyConfig());
    final trigger = SafetyTrigger(
      id: 'shake',
      type: TriggerType.shake,
      detectedAt: now,
    );
    final first = gate.request(trigger);
    expect(await gate.request(trigger), isFalse);
    expect(bridge.calls, 1);
    bridge.answer.complete(false);
    expect(await first, isFalse);
    expect(gate.isPending, isFalse);
  });
  test('confirmation errors release the pending gate', () async {
    final bridge = PendingConfirmation();
    final gate = ConfirmationGate(bridge, const SafetyConfig());
    final request = gate.request(
      SafetyTrigger(id: 'shake', type: TriggerType.shake, detectedAt: now),
    );
    final expectation = expectLater(request, throwsStateError);
    bridge.answer.completeError(StateError('UI unavailable'));
    await expectation;
    expect(gate.isPending, isFalse);
  });
}
