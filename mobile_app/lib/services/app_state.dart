import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Data layer: talks to the Flask backend. An SOS that has not reached the
/// server yet is also saved in encrypted storage and resent after a restart.
/// Screens only call this class, so they will not need rewriting.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

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
        DateTime.now().difference(existing.time) < const Duration(minutes: 30)) {
      return existing;
    }
    final e = EmergencyEvent(id: _id(), time: DateTime.now(), trigger: trigger);
    events.insert(0, e);
    unawaited(_savePending(e));
    _go();
    return e;
  }

  /// Writes the unsent SOS to encrypted storage. S05 only claims "kept even if
  /// the app restarts" when this really succeeded (e.savedOnDevice == true).
  Future<void> _savePending(EmergencyEvent e) async {
    e.savedOnDevice = await SessionStore.savePendingSos(e.toJson(), user?.phone ?? '');
    // The send or a cancel may have finished while we were writing: do not
    // leave a stale copy behind.
    if (e.syncStatus == 'received' || e.status != 'active') {
      await SessionStore.clearPendingSos(e.id);
    }
    _go();
  }

  /// POST /api/sos. e.id is a UUID, so retrying after a network drop is safe
  /// (the backend returns the first record instead of creating a duplicate).
  /// TODO: replace the fixed location with real GPS (M2's work). Until then
  /// every SOS is reported from AppConfig.campusCenter.
  Future<bool> sendEvent(EmergencyEvent e) async {
    lastSendError = null;
    if (!online) {
      lastSendError = 'Offline switch is on (demo)';
      _go();
      return false;
    }
    if (e.status != 'active') return false;
    final r = await ApiClient.I.post('/api/sos', {
      'id': e.id,
      'trigger': e.trigger,
      'latitude': AppConfig.campusCenter.latitude,
      'longitude': AppConfig.campusCenter.longitude,
      'timestamp': e.time.toUtc().toIso8601String(),
    });
    if (!r.ok) {
      lastSendError = r.error;
      _go();
      return false;
    }
    e.syncStatus = 'received';
    unawaited(SessionStore.clearPendingSos(e.id)); // the server has it now
    if (r.data['duplicate'] != true) {
      final alerts = ((r.data['alerts'] as List?) ?? [])
          .where((a) => a['channel'] == 'sms')
          .toList();
      final delivered =
          alerts.where((a) => a['status'] == 'sent' || a['status'] == 'simulated').length;
      final simulated = alerts.any((a) => a['status'] == 'simulated');
      if (delivered > 0) {
        e.contactsStatus = 'handed_off';
        e.alertDetail = '$delivered of ${alerts.length} contact(s) alerted'
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
    unawaited(ApiClient.I.post('/api/sos/${e.id}/resolve', {'status': status}));
  }

  void cancelEvent(EmergencyEvent e) {
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
        server.add(EmergencyEvent(
          id: id,
          time: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
          trigger: (j['trigger'] ?? 'button') as String,
          status: status,
          syncStatus: 'received',
          contactsStatus: 'unknown',
        ));
      }
    }
    final serverIds = server.map((e) => e.id).toSet();
    final pendingLocal =
        events.where((e) => e.syncStatus != 'received' && !serverIds.contains(e.id));
    final merged = [...pendingLocal, ...server];
    events
      ..clear()
      ..addAll(merged);
    _go();
  }

  void startLive() {
    if (liveSharing) return;
    liveSharing = true;
    liveSince = DateTime.now();
    _go();
  }

  void stopLive() {
    liveSharing = false;
    final e = activeEvent;
    if (e != null) {
      e.status = 'resolved';
      _closeOnServer(e, 'resolved');
    }
    _go();
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
