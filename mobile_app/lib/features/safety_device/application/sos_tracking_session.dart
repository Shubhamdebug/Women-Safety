import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../data/android_foreground_tracking_controller.dart';
import '../data/sos_payload_adapter.dart';
import '../domain/models.dart';
import '../domain/ports.dart';

typedef SosPost = Future<ApiResult> Function(
  String path,
  Map<String, dynamic> body,
);

/// A session sends at most one ping at a time and ignores completions after stop.
class SosTrackingSession extends ChangeNotifier {
  SosTrackingSession({
    required this.controller,
    required this.post,
    this.interval = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _stateSubscription = controller.states.listen((value) {
      if (_eventId == null) return;
      state = value;
      if (value == TrackingState.failed) {
        lastError = controller is AndroidForegroundTrackingController
            ? (controller as AndroidForegroundTrackingController).lastError
            : 'Location tracking stopped. Check permissions and retry.';
      }
      notifyListeners();
    });
    _locationSubscription = controller.locations.listen(_onLocation);
  }

  final ForegroundTrackingController controller;
  final SosPost post;
  final Duration interval;
  final DateTime Function() _now;
  late final StreamSubscription<TrackingState> _stateSubscription;
  late final StreamSubscription<LocationSnapshot> _locationSubscription;
  String? _eventId;
  String? get eventId => _eventId;
  int _generation = 0;
  bool _sending = false;
  DateTime? _lastAttempt;
  DateTime? lastPingAt;
  String? lastError;
  TrackingState state = TrackingState.stopped;

  Future<void> start(String eventId) async {
    if (_eventId == eventId &&
        (state == TrackingState.active || state == TrackingState.starting)) {
      return;
    }
    ++_generation;
    _eventId = eventId;
    _sending = false;
    _lastAttempt = null;
    lastPingAt = null;
    lastError = null;
    state = TrackingState.starting;
    notifyListeners();
    await controller.startTracking(eventId);
  }

  Future<void> _onLocation(LocationSnapshot location) async {
    final eventId = _eventId;
    final generation = _generation;
    final now = _now();
    if (eventId == null ||
        _sending ||
        (_lastAttempt != null && now.difference(_lastAttempt!) < interval)) {
      return;
    }
    _sending = true;
    _lastAttempt = now;
    try {
      final result = await post(
        '/api/sos/$eventId/location',
        SosPayloadAdapter.ping(location),
      );
      if (generation != _generation) return;
      if (result.status == 409 ||
          result.status == 401 ||
          result.status == 403) {
        final stopping = stop();
        final stoppedGeneration = _generation;
        await stopping;
        if (_generation != stoppedGeneration) return;
        lastError = result.status == 409
            ? 'The server reports that this SOS is closed.'
            : 'Sign in again before resuming location sharing.';
        notifyListeners();
        return;
      }
      final ping = result.data['ping'];
      if (result.ok &&
          ping is Map &&
          ping['latitude'] == location.latitude &&
          ping['longitude'] == location.longitude) {
        lastPingAt = now;
        lastError = null;
      } else {
        lastError = 'Location update was not acknowledged. Tracking will retry on the next fix.';
      }
    } catch (_) {
      if (generation != _generation) return;
      lastError =
          'Location update failed. Tracking will retry on the next fix.';
    } finally {
      if (generation == _generation) {
        _sending = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    ++_generation;
    _eventId = null;
    _sending = false;
    state = TrackingState.stopped;
    notifyListeners();
    await controller.stopTracking();
  }

  @override
  void dispose() {
    ++_generation;
    _eventId = null;
    unawaited(_stateSubscription.cancel());
    unawaited(_locationSubscription.cancel());
    if (controller is AndroidForegroundTrackingController) {
      unawaited((controller as AndroidForegroundTrackingController).dispose());
    } else {
      unawaited(controller.stopTracking());
    }
    super.dispose();
  }
}
