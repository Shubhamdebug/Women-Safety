import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wsa_app/features/safety_device/application/sos_tracking_session.dart';
import 'package:wsa_app/features/safety_device/data/android_foreground_tracking_controller.dart';
import 'package:wsa_app/features/safety_device/domain/ports.dart';
import 'package:wsa_app/services/api_client.dart';

import 'location_fakes.dart';

void main() {
  test(
    'Android stream has visible foreground notification and 30-second interval',
    () async {
      final platform = FakeGeolocator();
      final controller = AndroidForegroundTrackingController(
        platform: platform,
        isVisible: () => true,
        requestNotificationPermission: () async => true,
      );
      final states = <TrackingState>[];
      final subscription = controller.states.listen(states.add);
      await controller.startTracking('incident');
      final settings = platform.streamSettings! as AndroidSettings;
      expect(settings.intervalDuration, const Duration(seconds: 30));
      expect(settings.foregroundNotificationConfig?.setOngoing, isTrue);
      expect(settings.foregroundNotificationConfig?.enableWakeLock, isTrue);
      platform.positions.add(positionAt(DateTime.now()));
      expect(states.last, TrackingState.active);
      await controller.stopTracking();
      expect(platform.positions.hasListener, isFalse);
      expect(states.last, TrackingState.stopped);
      await subscription.cancel();
      await controller.dispose();
      await platform.close();
    },
  );
  test(
    'GPS-off and permission/stream errors stop the foreground session',
    () async {
      for (final disabled in [true, false]) {
        final platform = FakeGeolocator();
        final controller = AndroidForegroundTrackingController(
          platform: platform,
          isVisible: () => true,
          requestNotificationPermission: () async => true,
        );
        final states = <TrackingState>[];
        final subscription = controller.states.listen(states.add);
        await controller.startTracking('incident');
        if (disabled) {
          platform.services.add(ServiceStatus.disabled);
        } else {
          platform.positions.addError(PermissionDeniedException('revoked'));
        }
        await flushAsync();
        expect(states.last, TrackingState.failed);
        expect(platform.positions.hasListener, isFalse);
        await subscription.cancel();
        await controller.dispose();
        await platform.close();
      }
    },
  );
  test(
    'cancellation during notification prompt prevents a late service start',
    () async {
      final platform = FakeGeolocator();
      final answer = Completer<bool>();
      final controller = AndroidForegroundTrackingController(
        platform: platform,
        isVisible: () => true,
        requestNotificationPermission: () => answer.future,
      );
      final start = controller.startTracking('incident');
      await flushAsync();
      await controller.stopTracking();
      answer.complete(true);
      await start;
      expect(platform.streamSettings, isNull);
      await controller.dispose();
      await platform.close();
    },
  );
  test(
    'background start is rejected without opening a sensor stream',
    () async {
      final platform = FakeGeolocator();
      final controller = AndroidForegroundTrackingController(
        platform: platform,
        isVisible: () => false,
        requestNotificationPermission: () async => true,
      );
      await controller.startTracking('incident');
      expect(controller.lastError, contains('Open the app'));
      expect(platform.streamSettings, isNull);
      await controller.dispose();
      await platform.close();
    },
  );
  test('denied notification permission reports failure', () async {
    final platform = FakeGeolocator();
    final controller = AndroidForegroundTrackingController(
      platform: platform,
      isVisible: () => true,
      requestNotificationPermission: () async => false,
    );
    await controller.startTracking('incident');
    expect(controller.lastError, contains('notifications'));
    expect(platform.streamSettings, isNull);
    await controller.dispose();
    await platform.close();
  });
  test(
    'pings are throttled, acknowledged honestly and stop with the SOS',
    () async {
      final controller = FakeTrackingController();
      var now = DateTime.utc(2026, 11, 17);
      final paths = <String>[];
      final session = SosTrackingSession(
        controller: controller,
        now: () => now,
        post: (path, body) async {
          paths.add(path);
          expect(body['timestamp'], now.toIso8601String());
          return ApiResult(true, 201, {'ping': body}, null);
        },
      );
      await session.start('same-uuid');
      controller.locationEvents.add(snapshotAt(now));
      await flushAsync();
      controller.locationEvents.add(snapshotAt(now));
      await flushAsync();
      expect(paths, ['/api/sos/same-uuid/location']);
      now = now.add(const Duration(seconds: 30));
      controller.locationEvents.add(snapshotAt(now));
      await flushAsync();
      expect(paths.length, 2);
      expect(session.lastPingAt, now);
      await session.stop();
      now = now.add(const Duration(seconds: 30));
      controller.locationEvents.add(snapshotAt(now));
      await flushAsync();
      expect(paths.length, 2);
      session.dispose();
      await flushAsync();
      await controller.close();
    },
  );
  test('late ping response after stop cannot revive tracking', () async {
    final controller = FakeTrackingController();
    final response = Completer<ApiResult>();
    final session = SosTrackingSession(
      controller: controller,
      post: (_, _) => response.future,
    );
    await session.start('id');
    controller.locationEvents.add(snapshotAt(DateTime.now()));
    await flushAsync();
    await session.stop();
    response.complete(const ApiResult(true, 201, {'ping': {}}, null));
    await flushAsync();
    expect(session.state, TrackingState.stopped);
    expect(session.lastPingAt, isNull);
    session.dispose();
    await flushAsync();
    await controller.close();
  });
  test(
    'server failure retains tracking but never claims a successful ping',
    () async {
      final controller = FakeTrackingController();
      final session = SosTrackingSession(
        controller: controller,
        post: (_, _) async => const ApiResult(false, 500, {}, 'unavailable'),
      );
      await session.start('id');
      controller.locationEvents.add(snapshotAt(DateTime.now()));
      await flushAsync();
      expect(session.lastPingAt, isNull);
      expect(session.lastError, isNotNull);
      session.dispose();
      await flushAsync();
      await controller.close();
    },
  );
  test('server-closed SOS stops tracking', () async {
    final controller = FakeTrackingController();
    final session = SosTrackingSession(
      controller: controller,
      post: (_, _) async => const ApiResult(false, 409, {}, 'closed'),
    );
    await session.start('id');
    controller.locationEvents.add(snapshotAt(DateTime.now()));
    await flushAsync();
    expect(session.state, TrackingState.stopped);
    expect(controller.stops, 1);
    session.dispose();
    await flushAsync();
    await controller.close();
  });
}
