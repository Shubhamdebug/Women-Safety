import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// MOCK data layer (in memory, resets when the app restarts).
/// Later: swap the methods for Flask API calls + local SQLite.
/// Screens only call this class, so they will not need rewriting.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  // account
  final List<Account> _accounts = [];
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

  final _rnd = Random();
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_rnd.nextInt(9999)}';
  void _go() => notifyListeners();
  void changed() => _go();

  // ---------- S01 / S02 ----------
  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Returns an error message, or null on success.
  String? register(String name, String phone, String email, String password) {
    final dup = _accounts.any((a) =>
        a.email.toLowerCase() == email.toLowerCase() || _digits(a.phone) == _digits(phone));
    if (dup) return 'An account with this phone or email already exists.';
    _accounts.add(Account(name, phone, email, password));
    return null;
  }

  /// Returns an error message, or null on success.
  String? login(String identifier, String password) {
    if (_accounts.isEmpty) return 'No account found. Tap Register first.';
    final id = identifier.trim().toLowerCase();
    for (final a in _accounts) {
      final match = a.email.toLowerCase() == id || _digits(a.phone) == _digits(identifier);
      if (match && a.password == password) {
        user = a;
        _go();
        return null;
      }
    }
    return 'Incorrect phone/email or password.';
  }

  void logout() {
    user = null;
    liveSharing = false;
    _go();
  }

  void updateProfile(String name, String phone) {
    final u = user;
    if (u == null) return;
    user = Account(name, phone, u.email, u.password);
    final i = _accounts.indexWhere((a) => a.email == u.email);
    if (i >= 0) _accounts[i] = user!;
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
