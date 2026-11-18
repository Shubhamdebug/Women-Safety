import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../features/safety_device/application/sos_tracking_session.dart';
import '../features/safety_device/data/android_foreground_tracking_controller.dart';
import '../features/safety_device/data/android_location_repository.dart';
import '../features/safety_device/data/sos_payload_adapter.dart';
import '../features/safety_device/domain/models.dart' as device;
import '../features/safety_device/domain/ports.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Data layer: talks to the Flask backend. An SOS that has not reached the
/// server yet is also saved in encrypted storage and resent after a restart.
/// Screens only call this class, so they will not need rewriting.
class AppState extends ChangeNotifier {
  AppState._({
    LocationRepository? locations,
    SosPost? post,
    SosTrackingSession? tracking,
  }) : _locations = locations ?? AndroidLocationRepository(),
       _postSos = post ?? ApiClient.I.post,
       tracking =
           tracking ??
           SosTrackingSession(
             controller: AndroidForegroundTrackingController(),
             post: post ?? ApiClient.I.post,
           ) {
    this.tracking.addListener(_trackingChanged);
  }
  static final AppState I = AppState._();

  @visibleForTesting
  factory AppState.forDeviceTests({
    required LocationRepository locations,
    required SosPost post,
    required SosTrackingSession tracking,
  }) => AppState._(locations: locations, post: post, tracking: tracking);

  final LocationRepository _locations;
  final SosPost _postSos;
  final SosTrackingSession tracking;
  final Map<String, Future<bool>> _sends = {};
  Future<void> _pendingWrite = Future.value();

  void _trackingChanged() {
    liveSharing = tracking.state == TrackingState.active;
    _go();
  }

  String get locationDetail {
    final event = activeEvent;
    final location = event?.location;
    if (location != null) {
      final precision =
          location.precision == device.LocationPrecision.approximate
          ? 'Approximate'
          : 'Phone';
      final cached = location.source == device.LocationSource.cached
          ? ' (recent cached fix)'
          : '';
      return '$precision location$cached, accuracy about ${location.accuracyMeters.round()} m';
    }
    return switch (event?.locationFailure) {
      device.LocationFailure.denied =>
        'Location permission denied. Sending SOS without coordinates.',
      device.LocationFailure.permanentlyDenied =>
        'Location blocked. Allow it in phone settings.',
      device.LocationFailure.disabled =>
        'Phone location is off. Sending SOS without coordinates.',
      device.LocationFailure.timeout =>
        'GPS timed out. Sending SOS without coordinates.',
      device.LocationFailure.unavailable =>
        'Location unavailable. Sending SOS without coordinates.',
      null => 'Waiting for phone location...',
    };
  }

  String get trackingDetail =>
      tracking.lastError ??
      switch (tracking.state) {
        TrackingState.starting => 'Waiting for a GPS fix...',
        TrackingState.active =>
          tracking.lastPingAt == null
              ? 'Tracking active; waiting for server acknowledgment'
              : 'Updating about every 30 seconds. Last acknowledged at ${tracking.lastPingAt!.toLocal().toIso8601String().substring(11, 19)}',
        TrackingState.failed =>
          'Tracking unavailable. Check phone settings and retry.',
        TrackingState.stopped => 'Tracking stopped',
      };

  // account (the real accounts live on the backend)
  Account? user;
  bool _setupDone = false; // S13 (permissions) shows on first login only
  bool get setupDone => _setupDone;
  set setupDone(bool v) {
    _setupDone = v;
    unawaited(SessionStore.saveSetupDone(v)); // remembered across restarts
  }

  // device / settings (placeholders until sensors and GPS are connected)
  bool shakeProtection = true;
  bool online = true; // demo switch in Profile (debug builds)
  final Map<String, bool> permissions = {
    'Location': false,
    'Notifications': false,
    'Motion sensors': false,
    'SMS': false,
  };

  // live sharing
  bool liveSharing = false;
  DateTime? liveSince;
  String? lastSendError; // why the last SOS send failed, shown on S05

  /// An unsent SOS older than this is NOT resent after a restart (a late alert
  /// to contacts about a long-finished situation would only cause panic).
  static const pendingSosMaxAge = Duration(hours: 1);

  // shake trigger
  bool countdownOpen = false; // S04 is on screen (or about to be)
  bool sensorAvailable =
      true; // false when this device has no usable accelerometer

  /// An SOS started in the last 30 minutes. The same window createEvent() uses
  /// to reuse an event, so an old forgotten "active" event cannot block shaking.
  static const recentEventWindow = Duration(minutes: 30);
  bool get sosInProgress {
    final e = activeEvent;
    return e != null && DateTime.now().difference(e.time) < recentEventWindow;
  }

  /// True when a shake is allowed to open the countdown right now.
  DateTime? lastCountdownClosedAt; // set by S04 when it closes
  bool get shakeArmed {
    final closed = lastCountdownClosedAt;
    final coolingDown =
        closed != null &&
        DateTime.now().difference(closed) < AppConfig.shakeCooldown;
    return user != null &&
        setupDone &&
        shakeProtection &&
        !countdownOpen &&
        !sosInProgress &&
        !coolingDown;
  }

  /// True when the app restarted with an unsent SOS and resumed it.
  /// main.dart then opens the SOS status screen, which retries sending.
  bool resumedPendingSos = false;

  // data
  final List<Contact> contacts = [];
  final List<EmergencyEvent> events = [];
  final List<AnonymousReport> reports = [];

  static const _uuid = Uuid();

  /// Real UUID v4. The backend requires this for SOS ids (idempotency key).
  String _id() => _uuid.v4();
  void _go() => notifyListeners();
  void changed() => _go();

  // ---------- S01 / S02 ----------
  /// Backend wants digits with an optional leading +.
  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Calls POST /api/auth/register. Returns an error message, or null on success.
  Future<String?> register(String name, String phone, String email, String password) async {
    final r = await ApiClient.I.post('/api/auth/register', {
      'name': name,
      'phone': _digits(phone),
      'password': password,
      if (email.isNotEmpty) 'email': email, // optional on the backend
    });
    return r.ok ? null : r.error;
  }

  /// Calls POST /api/auth/login (phone + password). Returns an error message, or null on success.
  Future<String?> login(String phone, String password) async {
    final r = await ApiClient.I.post('/api/auth/login',
        {'phone': _digits(phone), 'password': password});
    if (!r.ok) return r.error;
    ApiClient.I.token = r.data['token'] as String?;
    final u = r.data['user'] as Map<String, dynamic>;
    user = Account(u['name'] as String, u['phone'] as String, (u['email'] ?? '') as String, '');
    await SessionStore.save(ApiClient.I.token!, user!.name, user!.phone);
    _go();
    await Future.wait([loadContacts(), loadHistory()]);
    return null;
  }

  /// Called once when the app starts. Returns true if the user is still logged in.
  /// - saved login rejected by the server (expired / user gone): forget it, show Login.
  /// - server unreachable: keep the saved login so the SOS screen still opens
  ///   (an offline safety app must not lock you out).
  Future<bool> restoreSession() async {
    _setupDone = await SessionStore.loadSetupDone();
    final saved = await SessionStore.load();
    if (saved == null) return false;
    ApiClient.I.token = saved.token;
    final r = await ApiClient.I.get('/api/auth/me').timeout(
          const Duration(seconds: 3),
          onTimeout: () => const ApiResult(false, 0, {}, 'timeout'),
        );
    if (r.status == 401) {
      ApiClient.I.token = null;
      await SessionStore.clear();
      await SessionStore.clearPendingSos();
      return false;
    }
    user = Account(saved.name, saved.phone, '', '');
    final fresh = r.data['user'];
    if (r.ok && fresh is Map<String, dynamic>) {
      user = Account(fresh['name'] as String, fresh['phone'] as String,
          (fresh['email'] ?? '') as String, '');
      await SessionStore.save(saved.token, user!.name, user!.phone);
    }
    await _resumePendingSos(saved.phone);
    unawaited(loadContacts());
    unawaited(loadHistory());
    return true;
  }

  /// If the app was closed while an SOS had not reached the server, bring it
  /// back so the SOS status screen can send it again (same UUID, so the
  /// server never creates a duplicate).
  Future<void> _resumePendingSos(String phone) async {
    final j = await SessionStore.loadPendingSos();
    if (j == null) return;
    final e = EmergencyEvent.fromJson(j);
    final tooOld = e == null || DateTime.now().difference(e.time) >= pendingSosMaxAge;
    if (e == null || tooOld || j['phone'] != phone) {
      await SessionStore.clearPendingSos();
      return;
    }
    events.insert(0, e);
    resumedPendingSos = true;
  }

  void logout() {
    unawaited(tracking.stop());
    user = null;
    ApiClient.I.token = null;
    resumedPendingSos = false;
    unawaited(SessionStore.clear());
    unawaited(SessionStore.clearPendingSos());
    contacts.clear();
    events.clear();
    liveSharing = false;
    _go();
  }

  /// PUT /api/auth/me. Returns an error message, or null on success.
  /// An empty email clears it (the email is optional on the backend).
  Future<String?> updateProfile(String name, String phone, String email) async {
    final r = await ApiClient.I.put('/api/auth/me',
        {'name': name, 'phone': _digits(phone), 'email': email});
    if (!r.ok) return r.error;
    final u = r.data['user'] as Map<String, dynamic>;
    user = Account(u['name'] as String, u['phone'] as String, (u['email'] ?? '') as String, '');
    await SessionStore.save(ApiClient.I.token!, user!.name, user!.phone);
    _go();
    return null;
  }

  // ---------- S07 / S08 ----------
  /// The backend allows at most 5 guardians per user.
  static const maxContacts = 5;

  Contact _contactFrom(dynamic j) => Contact(
      id: '${j['id']}',
      name: j['name'] as String,
      phone: j['phone'] as String,
      relationship: (j['relation'] ?? '') as String);

  /// GET /api/guardians
  Future<void> loadContacts() async {
    final r = await ApiClient.I.get('/api/guardians');
    if (!r.ok) return;
    final list = (r.data['guardians'] as List?) ?? [];
    contacts
      ..clear()
      ..addAll(list.map(_contactFrom));
    _go();
  }

  /// POST /api/guardians. Returns an error message, or null on success.
  Future<String?> addContact(String n, String p, String rel) async {
    final r = await ApiClient.I
        .post('/api/guardians', {'name': n, 'phone': p, 'relation': rel});
    if (!r.ok) return r.error;
    contacts.add(_contactFrom(r.data['guardian']));
    _go();
    return null;
  }

  /// DELETE /api/guardians/<id>. Returns an error message, or null on success.
  Future<String?> deleteContact(Contact c) async {
    final r = await ApiClient.I.delete('/api/guardians/${c.id}');
    if (!r.ok && r.status != 404) return r.error; // 404 = already gone
    contacts.remove(c);
    _go();
    return null;
  }

  /// PUT /api/guardians/<id>. Returns an error message, or null on success.
  Future<String?> updateContact(Contact c, String n, String p, String rel) async {
    if (c.name == n && c.phone == p && c.relationship == rel) return null;
    final r = await ApiClient.I
        .put('/api/guardians/${c.id}', {'name': n, 'phone': p, 'relation': rel});
    if (!r.ok) return r.error;
    final g = r.data['guardian'];
    c.name = g['name'] as String;
    c.phone = g['phone'] as String;
    c.relationship = (g['relation'] ?? '') as String;
    _go();
    return null;
  }

  // ---------- S04 / S05 / S06 / S10 ----------
  EmergencyEvent? get activeEvent {
    for (final e in events) {
      if (e.status == 'active') return e;
    }
    return null;
  }

  /// Reuses a RECENT active event (prevents duplicate SOS records). An old
  /// "active" event left over from an earlier session is not reused, otherwise
  /// a new SOS would silently be treated as the old one.
  EmergencyEvent createEvent(String trigger) {
    final existing = activeEvent;
    if (existing != null &&
        DateTime.now().difference(existing.time) < recentEventWindow) {
      return existing;
    }
    final e = EmergencyEvent(id: _id(), time: DateTime.now(), trigger: trigger);
    unawaited(tracking.stop());
    liveSince = null;
    events.insert(0, e);
    unawaited(_savePending(e));
    _go();
    return e;
  }

  /// Writes the unsent SOS to encrypted storage. S05 only claims "kept even if
  /// the app restarts" when this really succeeded (e.savedOnDevice == true).
  Future<void> _savePending(EmergencyEvent e) {
    final phone = user?.phone ?? '';
    // Serialize the initial and location-enriched writes to the existing store.
    return _pendingWrite = _pendingWrite.then((_) async {
      e.savedOnDevice = await SessionStore.savePendingSos(e.toJson(), phone);
      // The send or a cancel may have finished while we were writing: do not
      // leave a stale copy behind.
      if (e.syncStatus == 'received' ||
          e.status != 'active' ||
          user?.phone != phone) {
        await SessionStore.clearPendingSos(e.id);
      }
      _go();
    });
  }

  /// POST /api/sos. e.id is a UUID, so retrying after a network drop is safe
  /// (the backend returns the first record instead of creating a duplicate).
  Future<bool> sendEvent(EmergencyEvent e) => _sends.putIfAbsent(
    e.id,
    () => _sendEvent(e).whenComplete(() {
      _sends.remove(e.id);
    }),
  );

  Future<bool> _sendEvent(EmergencyEvent e) async {
    final owner = user;
    lastSendError = null;
    if (e.status != 'active' || owner == null) return false;
    // The initial pending record survives a process exit during permission/GPS work.
    await _pendingWrite;
    if (e.location == null) {
      device.LocationResult result;
      try {
        result = await _locations.capture();
      } catch (_) {
        result = const device.LocationResult(
          failure: device.LocationFailure.unavailable,
        );
      }
      if (e.status != 'active' || user != owner) return false;
      e.location = result.snapshot;
      e.locationFailure = result.failure;
      await _savePending(e);
    }
    if (e.status != 'active' || user != owner) return false;
    if (!online) {
      lastSendError = 'Offline switch is on (demo)';
      _go();
      return false;
    }
    if (e.status != 'active') return false;
    final r = await _postSos('/api/sos', SosPayloadAdapter.create(e));
    if (user != owner) return false;
    if (!r.ok) {
      lastSendError = e.location == null && r.status == 400
          ? 'Server rejected an SOS without location. The SOS remains pending; enable GPS and retry.'
          : r.error;
      _go();
      return false;
    }
    final incident = r.data['incident'];
    if (incident is! Map || incident['id'] != e.id) {
      lastSendError =
          'The server did not acknowledge this SOS ID. It remains pending.';
      _go();
      return false;
    }
    e.syncStatus = 'received';
    unawaited(SessionStore.clearPendingSos(e.id)); // the server has it now
    if (r.data['duplicate'] != true) {
      final alerts = ((r.data['alerts'] as List?) ?? [])
          .where((a) => a['channel'] == 'sms')
          .toList();
      final delivered = alerts
          .where((a) => a['status'] == 'sent' || a['status'] == 'simulated')
          .length;
      final simulated = alerts.any((a) => a['status'] == 'simulated');
      if (delivered > 0) {
        e.contactsStatus = 'handed_off';
        e.alertDetail =
            '$delivered of ${alerts.length} contact(s) alerted'
            '${simulated ? ' (demo: SMS is simulated)' : ''}';
      } else {
        e.contactsStatus = 'not_notified';
        e.alertDetail = alerts.isEmpty
            ? 'No emergency contacts saved. Add contacts first.'
            : 'SMS to contacts failed';
      }
    }
    // The user cancelled while the request was in flight: close it on the server too.
    if (e.status != 'active') _closeOnServer(e, e.status);
    _go();
    return true;
  }

  /// Tells the server the SOS is over. Best effort: if it fails, the local
  /// state is still closed.
  void _closeOnServer(EmergencyEvent e, String status) {
    if (e.syncStatus != 'received') return; // the server never heard about it
    unawaited(_postSos('/api/sos/${e.id}/resolve', {'status': status}));
  }

  void cancelEvent(EmergencyEvent e) {
    unawaited(tracking.stop());
    e.status = 'cancelled';
    liveSharing = false;
    unawaited(SessionStore.clearPendingSos(e.id));
    _closeOnServer(e, 'cancelled');
    _go();
  }

  /// GET /api/sos/mine. Merges with local events so an SOS that has not
  /// reached the server yet is not lost.
  Future<void> loadHistory() async {
    final r = await ApiClient.I.get('/api/sos/mine');
    if (!r.ok) return;
    final local = {for (final e in events) e.id: e};
    final server = <EmergencyEvent>[];
    for (final j in (r.data['incidents'] as List?) ?? []) {
      final id = j['id'] as String;
      final status = (j['status'] ?? 'active') as String;
      final known = local[id];
      if (known != null) {
        known.status = status;
        server.add(known);
      } else {
        server.add(
          EmergencyEvent(
            id: id,
            time:
                DateTime.tryParse('${j['created_at']}')?.toLocal() ??
                DateTime.now(),
            trigger: (j['trigger'] ?? 'button') as String,
            status: status,
            syncStatus: 'received',
            contactsStatus: 'unknown',
          ),
        );
      }
    }
    final serverIds = server.map((e) => e.id).toSet();
    final pendingLocal = events.where(
      (e) => e.syncStatus != 'received' && !serverIds.contains(e.id),
    );
    final merged = [...pendingLocal, ...server];
    events
      ..clear()
      ..addAll(merged);
    final trackedId = tracking.eventId;
    if (trackedId != null &&
        !events.any((event) => event.id == trackedId && event.status == 'active')) {
      unawaited(tracking.stop());
    }
    _go();
  }

  Future<void> startLive() async {
    final event = activeEvent;
    if (event == null || event.syncStatus != 'received') {
      lastSendError = 'Send an SOS successfully before starting live location.';
      _go();
      return;
    }
    liveSince ??= DateTime.now();
    await tracking.start(event.id);
    _go();
  }

  void stopLive() {
    unawaited(tracking.stop());
    liveSharing = false;
    final e = activeEvent;
    if (e != null) {
      e.status = 'resolved';
      unawaited(SessionStore.clearPendingSos(e.id));
      _closeOnServer(e, 'resolved');
    }
    _go();
  }

  @override
  void dispose() {
    tracking.removeListener(_trackingChanged);
    tracking.dispose();
    super.dispose();
  }

  // ---------- S12 ----------
  /// App label -> code the backend accepts (GET /api/reports/categories).
  /// The report screen builds its dropdown from these keys, so they cannot drift apart.
  static const reportCategories = {
    'Harassment': 'harassment',
    'Stalking': 'stalking',
    'Unsafe location': 'unsafe_area',
    'Suspicious activity': 'suspicious_activity',
    'Poor lighting': 'poor_lighting',
    'Other safety concern': 'other',
  };

  /// POST /api/reports. ANONYMOUS: the login token is deliberately NOT sent.
  /// The backend has no "place name" field, so the typed location goes at the
  /// start of the description (the backend keeps only the first 500 characters).
  /// Returns an error message, or null on success.
  Future<String?> submitReport(String cat, String loc, String desc, DateTime when,
      double lat, double lng) async {
    var text = 'Location: $loc${desc.isEmpty ? '' : '\n$desc'}';
    if (text.length > 500) text = text.substring(0, 500);
    final now = DateTime.now();
    final r = await ApiClient.I.post(
      '/api/reports',
      {
        'category': reportCategories[cat] ?? 'other',
        'latitude': lat,
        'longitude': lng,
        'description': text,
        'timestamp': (when.isAfter(now) ? now : when).toUtc().toIso8601String(),
      },
      auth: false,
    );
    if (!r.ok) return r.error;
    reports.add(AnonymousReport(
        category: cat, locationText: loc, description: desc,
        incidentTime: when, createdAt: now, lat: lat, lng: lng));
    _go();
    return null;
  }
}
