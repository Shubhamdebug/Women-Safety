import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wsa_app/features/safety_device/data/android_location_repository.dart';
import 'package:wsa_app/features/safety_device/domain/models.dart';
import 'package:wsa_app/features/safety_device/domain/safety_config.dart';

import 'location_fakes.dart';

void main() {
  late FakeGeolocator platform;
  late AndroidLocationRepository repository;
  final now = DateTime.utc(2026, 11, 17, 10);
  setUp(() {
    platform = FakeGeolocator()..fix = (() async => positionAt(now));
    repository = AndroidLocationRepository(platform: platform, now: () => now);
  });
  tearDown(() => platform.close());

  test(
    'granted permission returns a real fix with UTC timestamp and accuracy',
    () async {
      final result = await repository.capture();
      expect(result.snapshot?.latitude, 12.5);
      expect(result.snapshot?.accuracyMeters, 8);
      expect(result.snapshot?.capturedAtUtc, now);
      expect(result.snapshot?.source, LocationSource.current);
      expect(result.failure, isNull);
    },
  );
  test('requests foreground permission when needed', () async {
    platform.permission = LocationPermission.denied;
    expect((await repository.capture()).snapshot, isNotNull);
    expect(platform.permissionRequests, 1);
  });
  test('denied returns a reason and never requests a fix', () async {
    platform.permission = platform.requestedPermission =
        LocationPermission.denied;
    final result = await repository.capture();
    expect(result.failure, LocationFailure.denied);
    expect(result.snapshot, isNull);
    expect(platform.fixRequests, 0);
  });
  test('permanent denial does not prompt again', () async {
    platform.permission = LocationPermission.deniedForever;
    expect(
      (await repository.capture()).failure,
      LocationFailure.permanentlyDenied,
    );
    expect(platform.permissionRequests, 0);
  });
  test('GPS off returns disabled without leaking cached coordinates', () async {
    platform.enabled = false;
    platform.cached = positionAt(now);
    final result = await repository.capture();
    expect(result.failure, LocationFailure.disabled);
    expect(result.snapshot, isNull);
  });
  test('hung platform acquisition is bounded by configured timeout', () async {
    platform.fix = () => Completer<Position>().future;
    repository = AndroidLocationRepository(
      platform: platform,
      now: () => now,
      config: const SafetyConfig(locationTimeout: Duration(milliseconds: 10)),
    );
    expect((await repository.capture()).failure, LocationFailure.timeout);
  });
  test(
    'approximate-only permission still returns usable coordinates',
    () async {
      platform.accuracy = LocationAccuracyStatus.reduced;
      platform.fix = () async => positionAt(now, accuracy: 1000);
      final result = await repository.capture();
      expect(result.snapshot?.precision, LocationPrecision.approximate);
      expect(result.snapshot?.accuracyMeters, 1000);
      expect(result.failure, isNull);
    },
  );
  test(
    'timeout uses fresh cache and retains the acquisition failure',
    () async {
      platform.fix = () async => throw TimeoutException('no fix');
      platform.cached = positionAt(now.subtract(const Duration(seconds: 30)));
      final result = await repository.capture();
      expect(result.snapshot?.source, LocationSource.cached);
      expect(result.failure, LocationFailure.timeout);
    },
  );
  test('stale and future cached positions are rejected', () async {
    platform.fix = () async => throw TimeoutException('no fix');
    for (final time in [
      now.subtract(const Duration(minutes: 3)),
      now.add(const Duration(minutes: 1)),
    ]) {
      platform.cached = positionAt(time);
      expect((await repository.capture()).snapshot, isNull);
    }
  });
  test('revoked permission during acquisition returns denial', () async {
    platform.fix = () async {
      platform.permission = LocationPermission.deniedForever;
      throw PermissionDeniedException('revoked');
    };
    expect(
      (await repository.capture()).failure,
      LocationFailure.permanentlyDenied,
    );
  });
  test('unexpected platform failure becomes unavailable', () async {
    platform.fix = () async => throw StateError('platform failed');
    expect((await repository.capture()).failure, LocationFailure.unavailable);
  });
}
