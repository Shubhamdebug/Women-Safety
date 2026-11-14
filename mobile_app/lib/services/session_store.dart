import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What we keep on the device so the user stays logged in after the app restarts.
class SavedSession {
  final String token, name, phone;
  const SavedSession(this.token, this.name, this.phone);
}

/// Encrypted on-device storage for the login token. Every call is wrapped in
/// try/catch: a storage problem must never stop the app from opening.
class SessionStore {
  static const _s = FlutterSecureStorage();

  static Future<void> save(String token, String name, String phone) async {
    try {
      await _s.write(key: 'token', value: token);
      await _s.write(key: 'name', value: name);
      await _s.write(key: 'phone', value: phone);
    } catch (_) {}
  }

  static Future<SavedSession?> load() async {
    try {
      final token = await _s.read(key: 'token');
      final name = await _s.read(key: 'name');
      final phone = await _s.read(key: 'phone');
      if (token == null || name == null || phone == null) return null;
      return SavedSession(token, name, phone);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _s.delete(key: 'token');
      await _s.delete(key: 'name');
      await _s.delete(key: 'phone');
    } catch (_) {}
  }

  static Future<bool> loadSetupDone() async {
    try {
      return await _s.read(key: 'setup_done') == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveSetupDone(bool v) async {
    try {
      await _s.write(key: 'setup_done', value: v ? '1' : '0');
    } catch (_) {}
  }
}
