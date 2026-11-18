import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/safety_config.dart';

class AndroidForegroundTrackingController
    implements ForegroundTrackingController {
  AndroidForegroundTrackingController({
    GeolocatorPlatform? platform,
    this.config = const SafetyConfig(),
    Future<bool> Function()? requestNotificationPermission,
    bool Function()? isVisible,
  }) : _platform = platform ?? GeolocatorPlatform.instance,
       _requestNotificationPermission =
           requestNotificationPermission ??
           (() async => (await Permission.notification.request()).isGranted),
       _isVisible =
           isVisible ??
           (() =>
               WidgetsBinding.instance.lifecycleState ==
               AppLifecycleState.resumed) {
    config.validate();
  }

  final GeolocatorPlatform _platform;
  final SafetyConfig config;
  final Future<bool> Function() _requestNotificationPermission;
  final bool Function() _isVisible;
  final _states = StreamController<TrackingState>.broadcast(sync: true);
  final _locations = StreamController<LocationSnapshot>.broadcast(sync: true);
  StreamSubscription<Position>? _positions;
  StreamSubscription<ServiceStatus>? _serviceStatus;
  int _generation = 0;
  String? lastError;

  @override
  Stream<TrackingState> get states => _states.stream;
  @override
  Stream<LocationSnapshot> get locations => _locations.stream;

  @override
  Future<void> startTracking(String sessionId) async {
    final generation = ++_generation;
    await _cancelStreams();
    if (generation != _generation) return;
    lastError = null;
    _states.add(TrackingState.starting);
    try {
      if (!_isVisible()) {
        throw StateError('Open the app to start location tracking.');
      }
      final permission = await _platform.checkPermission();
      if (generation != _generation) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw StateError(
          'Allow location access in phone settings to start tracking.',
        );
      }
      if (!await _platform.isLocationServiceEnabled()) {
        throw StateError('Turn on phone location to start tracking.');
      }
      if (generation != _generation) return;
      if (!await _requestNotificationPermission()) {
        throw StateError(
          'Allow notifications to show the tracking notification.',
        );
      }
      if (generation != _generation) return;
      if (!_isVisible()) throw StateError('Open the app and retry tracking.');
      final accuracy = await _platform.getLocationAccuracy();
      if (generation != _generation) return;
      if (!_isVisible()) throw StateError('Open the app and retry tracking.');
      _serviceStatus = _platform.getServiceStatusStream().listen(
        (status) {
          if (status == ServiceStatus.disabled) {
            unawaited(_fail(generation, 'Phone location was switched off.'));
          }
        },
        onError: (Object error) {
          unawaited(_fail(generation, 'Location service is unavailable.'));
        },
      );
      _positions = _platform
          .getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: config.trackingInterval,
              timeLimit: const Duration(minutes: 2),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'KAVACH SOS location sharing',
                notificationText:
                    'Location tracking is active. Open KAVACH to stop sharing.',
                enableWakeLock: true,
                setOngoing: true,
              ),
            ),
          )
          .listen(
            (p) {
              if (generation != _generation) return;
              try {
                final snapshot = LocationSnapshot(
                  latitude: p.latitude,
                  longitude: p.longitude,
                  accuracyMeters: p.accuracy,
                  capturedAt: p.timestamp,
                  source: LocationSource.current,
                  precision: accuracy == LocationAccuracyStatus.reduced
                      ? LocationPrecision.approximate
                      : LocationPrecision.precise,
                );
                if (!snapshot.isFreshAt(
                  DateTime.now(),
                  config.maximumCachedLocationAge,
                )) {
                  return;
                }
                _states.add(TrackingState.active);
                _locations.add(snapshot);
              } catch (_) {
                unawaited(
                  _fail(generation, 'The phone returned an invalid location.'),
                );
              }
            },
            onError: (Object error) {
              unawaited(
                _fail(
                  generation,
                  'Tracking stopped. Check location permission and GPS, then retry.',
                ),
              );
            },
            onDone: () {
              unawaited(
                _fail(
                  generation,
                  'The location stream stopped. Retry tracking.',
                ),
              );
            },
          );
    } catch (error) {
      await _fail(
        generation,
        error is StateError
            ? error.message.toString()
            : 'Tracking could not start. Check phone permissions.',
      );
    }
  }

  Future<void> _fail(int generation, String message) async {
    if (generation != _generation) return;
    ++_generation;
    lastError = message;
    _states.add(TrackingState.failed);
    await _cancelStreams();
  }

  Future<void> _cancelStreams() async {
    final positions = _positions;
    final serviceStatus = _serviceStatus;
    _positions = null;
    _serviceStatus = null;
    await positions?.cancel();
    await serviceStatus?.cancel();
  }

  @override
  Future<void> stopTracking() async {
    ++_generation;
    _states.add(TrackingState.stopped);
    await _cancelStreams();
  }

  Future<void> dispose() async {
    await stopTracking();
    await _states.close();
    await _locations.close();
  }
}
