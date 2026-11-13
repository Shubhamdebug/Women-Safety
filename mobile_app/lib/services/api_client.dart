import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Result of one backend call. The backend always answers JSON; errors look like
/// {"error": "message"}.
class ApiResult {
  final bool ok;
  final int status;
  final Map<String, dynamic> data;
  final String? error;
  const ApiResult(this.ok, this.status, this.data, this.error);
}

/// Thin wrapper around the Flask backend (see backend/README.md for the API reference).
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  /// JWT from /api/auth/login. Kept in memory only for now.
  String? token;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<ApiResult> post(String path, Map<String, dynamic> body) =>
      _send(() => http.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<ApiResult> get(String path) => _send(() => http.get(_uri(path), headers: _headers));

  Future<ApiResult> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers));

  Future<ApiResult> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 10));
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      final err = ok ? null : (data['error']?.toString() ?? 'Server error (${res.statusCode}).');
      return ApiResult(ok, res.statusCode, data, err);
    } on TimeoutException {
      return const ApiResult(false, 0, {}, 'Server did not respond. Check Wi-Fi and server address.');
    } catch (_) {
      return const ApiResult(false, 0, {}, 'Cannot reach the server. Is it running, on the same Wi-Fi?');
    }
  }
}
