import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wsa_app/features/safety_device/application/sos_tracking_session.dart';
import 'package:wsa_app/features/safety_device/data/sos_payload_adapter.dart';
import 'package:wsa_app/features/safety_device/domain/models.dart' as device;
import 'package:wsa_app/features/safety_device/domain/ports.dart';
import 'package:wsa_app/models/models.dart' as app;
import 'package:wsa_app/services/api_client.dart';
import 'package:wsa_app/services/app_state.dart';

import 'location_fakes.dart';

class TestLocationRepository implements LocationRepository {
  TestLocationRepository(this.result);
  final Future<device.LocationResult> Function() result;
  @override
  Future<device.LocationResult> capture() => result();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = <String, String>{};
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late FakeTrackingController controller;
  late AppState state;
  setUp(() {
    storage.clear();
    controller = FakeTrackingController();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String;
          if (call.method == 'write') storage[key] = args['value'] as String;
          if (call.method == 'delete') storage.remove(key);
          if (call.method == 'read') return storage[key];
          return null;
        });
  });
  tearDown(() async {
    state.dispose();
    await flushAsync();
    await controller.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  void configure(
    Future<device.LocationResult> Function() capture,
    SosPost post,
  ) {
    state = AppState.forDeviceTests(
      locations: TestLocationRepository(capture),
      post: post,
      tracking: SosTrackingSession(controller: controller, post: post),
    );
    state.user = app.Account('Test', 'test-owner', '', '');
  }

  test('each GPS failure sends without invented coordinates and retains rejected SOS', () async {
    var failure = device.LocationFailure.denied;
    final bodies = <Map<String, dynamic>>[];
    configure(() async => device.LocationResult(failure: failure), (
      path,
      body,
    ) async {
      expect(path, '/api/sos');
      expect(storage['pending_sos'], isNotNull);
      bodies.add(body);
      return const ApiResult(
        false,
        400,
        {},
        'Valid latitude and longitude are required.',
      );
    });
    final event = state.createEvent('button');
    for (final reason in device.LocationFailure.values) {
      failure = reason;
      expect(await state.sendEvent(event), isFalse);
      expect(event.locationFailure, reason);
      expect(event.syncStatus, 'pending');
      expect(event.savedOnDevice, isTrue);
      expect(bodies.last.containsKey('latitude'), isFalse);
      expect(bodies.last.containsKey('longitude'), isFalse);
      final saved = jsonDecode(storage['pending_sos']!) as Map<String, dynamic>;
      expect(saved['id'], event.id);
      expect(saved['locationFailure'], reason.name);
    }
    expect(bodies.map((b) => b['id']).toSet(), {event.id});
  });
  test('current coordinates replace campus placeholder and matching ack clears pending', () async {
    configure(
      () async => device.LocationResult(snapshot: snapshotAt(DateTime.now())),
      (path, body) async {
        if (path.endsWith('/resolve')) {
          return const ApiResult(true, 200, {}, null);
        }
        expect(body['latitude'], 12.5);
        expect(body['longitude'], 77.5);
        expect(body['trigger'], 'button');
        expect(body.containsKey('eventId'), isFalse);
        return ApiResult(true, 201, {
          'incident': {'id': body['id']},
          'alerts': [],
        }, null);
      },
    );
    final event = state.createEvent('manual');
    expect(await state.sendEvent(event), isTrue);
    await flushAsync();
    expect(event.syncStatus, 'received');
    expect(storage.containsKey('pending_sos'), isFalse);
    await state.startLive();
    expect(controller.starts, 1);
    state.cancelEvent(event);
    await flushAsync();
    expect(controller.stops, greaterThan(0));
  });
  test('cancelling while GPS is pending prevents the POST', () async {
    final fix = Completer<device.LocationResult>();
    var posts = 0;
    configure(() => fix.future, (_, _) async {
      posts++;
      return const ApiResult(false, 500, {}, null);
    });
    final event = state.createEvent('button');
    final sending = state.sendEvent(event);
    await flushAsync();
    state.cancelEvent(event);
    fix.complete(
      const device.LocationResult(failure: device.LocationFailure.timeout),
    );
    expect(await sending, isFalse);
    expect(posts, 0);
  });
  test(
    'logout while GPS is pending prevents a POST under another account',
    () async {
      final fix = Completer<device.LocationResult>();
      var posts = 0;
      configure(() => fix.future, (_, _) async {
        posts++;
        return const ApiResult(false, 500, {}, null);
      });
      final event = state.createEvent('button');
      final sending = state.sendEvent(event);
      await flushAsync();
      state.logout();
      fix.complete(device.LocationResult(snapshot: snapshotAt(DateTime.now())));
      expect(await sending, isFalse);
      expect(posts, 0);
    },
  );
  test(
    'overlapping retries share one capture and one backend request',
    () async {
      final response = Completer<ApiResult>();
      var posts = 0;
      configure(
        () async => device.LocationResult(snapshot: snapshotAt(DateTime.now())),
        (_, body) {
          posts++;
          return response.future;
        },
      );
      final event = state.createEvent('button');
      final first = state.sendEvent(event);
      final second = state.sendEvent(event);
      await flushAsync();
      response.complete(
        ApiResult(true, 200, {
          'incident': {'id': event.id},
          'duplicate': true,
        }, null),
      );
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(posts, 1);
    },
  );
  test('mismatched acknowledgment never marks the event received', () async {
    configure(
      () async => device.LocationResult(snapshot: snapshotAt(DateTime.now())),
      (_, _) async => const ApiResult(true, 201, {
        'incident': {'id': 'wrong-id'},
      }, null),
    );
    final event = state.createEvent('button');
    expect(await state.sendEvent(event), isFalse);
    expect(event.syncStatus, 'pending');
    expect(storage['pending_sos'], isNotNull);
  });
  test(
    'old stored events and corrupt optional metadata retain their UUID',
    () async {
      configure(
        () async => const device.LocationResult(),
        (_, _) async => const ApiResult(false, 0, {}, null),
      );
      final original = {
        'id': 'old-uuid',
        'time': '2026-11-17T00:00:00Z',
        'trigger': 'shake',
      };
      final old = app.EmergencyEvent.fromJson(original)!;
      expect(old.id, 'old-uuid');
      expect(old.location, isNull);
      final damaged = app.EmergencyEvent.fromJson({
        ...original,
        'location': {'latitude': 'broken'},
      })!;
      expect(damaged.id, 'old-uuid');
      expect(damaged.locationFailure, device.LocationFailure.unavailable);
      final approximate = snapshotAt(DateTime.now());
      old.location = approximate;
      final restored = app.EmergencyEvent.fromJson(
        jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>,
      )!;
      expect(restored.location?.latitude, approximate.latitude);
      for (final trigger in [
        'manual',
        'button',
        'shake',
        'timer',
        'voice',
        'unknown',
      ]) {
        final event = app.EmergencyEvent(
          id: 'id',
          time: DateTime.now(),
          trigger: trigger,
        );
        expect(
          SosPayloadAdapter.acceptedTriggers,
          contains(SosPayloadAdapter.create(event)['trigger']),
        );
      }
    },
  );
}
