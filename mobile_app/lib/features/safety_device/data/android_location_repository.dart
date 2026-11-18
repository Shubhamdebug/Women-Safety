import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/safety_config.dart';

class AndroidLocationRepository implements LocationRepository {
  AndroidLocationRepository({
    GeolocatorPlatform? platform,
    this.config = const SafetyConfig(),
    DateTime Function()? now,
  }) : platform = platform ?? GeolocatorPlatform.instance,
       _now = now ?? DateTime.now {
    config.validate();
  }

  final GeolocatorPlatform platform;
  final SafetyConfig config;
  final DateTime Function() _now;

  @override
  Future<LocationResult> capture() async {
    try {
      var permission = await platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(failure: LocationFailure.permanentlyDenied);
      }
      if (!_allowed(permission)) {
        return const LocationResult(failure: LocationFailure.denied);
      }
      if (!await platform.isLocationServiceEnabled()) {
        return const LocationResult(failure: LocationFailure.disabled);
      }
      final position = await platform
          .getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: config.locationTimeout,
            ),
          )
          .timeout(config.locationTimeout);
      final snapshot = await _snapshot(position, LocationSource.current);
      if (!snapshot.isFreshAt(_now(), config.maximumCachedLocationAge)) {
        return await _cached(LocationFailure.unavailable);
      }
      return LocationResult(snapshot: snapshot);
    } on TimeoutException {
      return _cached(LocationFailure.timeout);
    } on PermissionDeniedException {
      return _permissionFailure();
    } on LocationServiceDisabledException {
      return const LocationResult(failure: LocationFailure.disabled);
    } catch (_) {
      return _cached(LocationFailure.unavailable);
    }
  }

  bool _allowed(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  Future<LocationResult> _permissionFailure() async {
    try {
      final p = await platform.checkPermission();
      return LocationResult(
        failure: p == LocationPermission.deniedForever
            ? LocationFailure.permanentlyDenied
            : LocationFailure.denied,
      );
    } catch (_) {
      return const LocationResult(failure: LocationFailure.denied);
    }
  }

  Future<LocationResult> _cached(LocationFailure reason) async {
    // Recheck access after a timeout; revoked permission must not expose cache.
    try {
      final permission = await platform.checkPermission();
      if (!_allowed(permission)) return await _permissionFailure();
      if (!await platform.isLocationServiceEnabled()) {
        return const LocationResult(failure: LocationFailure.disabled);
      }
      final position = await platform.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
      );
      if (position != null) {
        final snapshot = await _snapshot(position, LocationSource.cached);
        if (snapshot.isFreshAt(_now(), config.maximumCachedLocationAge)) {
          return LocationResult(snapshot: snapshot, failure: reason);
        }
      }
    } catch (_) {
      // Preserve the original acquisition failure when cache is also unavailable.
    }
    return LocationResult(failure: reason);
  }

  Future<LocationSnapshot> _snapshot(Position p, LocationSource source) async {
    var precision = LocationPrecision.unknown;
    try {
      final status = await platform.getLocationAccuracy().timeout(
        const Duration(seconds: 2),
      );
      precision = status == LocationAccuracyStatus.reduced
          ? LocationPrecision.approximate
          : LocationPrecision.precise;
    } catch (_) {
      // Accuracy metadata failure does not discard a valid position.
    }
    return LocationSnapshot(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: p.accuracy,
      capturedAt: p.timestamp,
      source: source,
      precision: precision,
    );
  }
}
