import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'api_client.dart';

/// MOCK data layer (in memory, resets when the app restarts).
/// Later: swap the methods for Flask API calls + local SQLite.
/// Screens only call this class, so they will not need rewriting.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  // account (the real accounts live on the backend)
  Account? user;
  bool setupDone = false; // S13 shows on first login only

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
  /// NOTE: the backend stores name, phone and password only. Email is not sent.
  Future<String?> register(String name, String phone, String email, String password) async {
    final r = await ApiClient.I.post('/api/auth/register',
        {'name': name, 'phone': _digits(phone), 'password': password});
    return r.ok ? null : r.error;
  }

  /// Calls POST /api/auth/login (phone + password). Returns an error message, or null on success.
  Future<String?> login(String phone, String password) async {
    final r = await ApiClient.I.post('/api/auth/login',
        {'phone': _digits(phone), 'password': password});
    if (!r.ok) return r.error;
    ApiClient.I.token = r.data['token'] as String?;
    final u = r.data['user'] as Map<String, dynamic>;
    user = Account(u['name'] as String, u['phone'] as String, '', '');
    _go();
    return null;
  }

  void logout() {
    user = null;
    ApiClient.I.token = null;
    liveSharing = false;
    _go();
  }

  /// Local only for now. The backend has no profile-update endpoint yet.
  void updateProfile(String name, String phone) {
    final u = user;
    if (u == null) return;
    user = Account(name, phone, u.email, u.password);
    _go();
  }

  // ---------- S07 / S08 ----------
  void addContact(String n, String p, String rel) {
    contacts.add(Contact(id: _id(), name: n, phone: p, relationship: rel));
    _go();
  }

  void updateContact(Contact c, String n, String p, String rel) {
    c.name = n; c.phone = p; c.relationship = rel;
    _go();
  }

  void deleteContact(Contact c) {
    contacts.remove(c);
    _go();
  }

  // ---------- S04 / S05 / S06 ----------
  EmergencyEvent? get activeEvent {
    for (final e in events) {
      if (e.status == 'active') return e;
    }
    return null;
  }

  /// Reuses the active event if there is one (prevents duplicate SOS records).
  EmergencyEvent createEvent(String trigger) {
    final existing = activeEvent;
    if (existing != null) return existing;
    final e = EmergencyEvent(id: _id(), time: DateTime.now(), trigger: trigger);
    events.insert(0, e);
    _go();
    return e;
  }

  /// MOCK send. Real version: POST /api/emergency using e.id as the
  /// idempotency key, and queue in SQLite when offline.
  Future<bool> sendEvent(EmergencyEvent e) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!online) {
      _go();
      return false;
    }
    if (e.status != 'active') return false;
    e.syncStatus = 'received';
    _go();
    return true;
  }

  void cancelEvent(EmergencyEvent e) {
    e.status = 'cancelled';
    liveSharing = false;
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
    if (e != null) e.status = 'resolved';
    _go();
  }

  // ---------- S12 ----------
  void submitReport(String cat, String loc, String desc, DateTime when, double? lat, double? lng) {
    reports.add(AnonymousReport(
      category: cat, locationText: loc, description: desc,
      incidentTime: when, createdAt: DateTime.now(), lat: lat, lng: lng));
    _go();
  }
}
