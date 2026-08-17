import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'auth_debug.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});
  final String message;
  final int? statusCode;
  final dynamic body;

  @override
  String toString() => message;
}

/// Thin HTTP client for Campus Essentials API (`{ success, message, data }`).
class ApiClient {
  ApiClient({
    required this.config,
    required this.session,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final EnvConfig config;
  final SessionStore session;
  final http.Client _http;
  bool _refreshing = false;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await session.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    final uri = _uri(path, query);
    return _send(
      () async => _http.get(
        uri,
        headers: await _headers(auth: auth),
      ),
      auth: auth,
      method: 'GET',
      uri: uri,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    final uri = _uri(path);
    return _send(
      () async => _http.post(
        uri,
        headers: await _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
      method: 'POST',
      uri: uri,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    final uri = _uri(path);
    return _send(
      () async => _http.put(
        uri,
        headers: await _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
      method: 'PUT',
      uri: uri,
    );
  }

  Future<dynamic> delete(String path, {bool auth = true}) {
    final uri = _uri(path);
    return _send(
      () async => _http.delete(
        uri,
        headers: await _headers(auth: auth),
      ),
      auth: auth,
      method: 'DELETE',
      uri: uri,
    );
  }

  /// Multipart upload (e.g. product images). Does not set Content-Type manually.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    required List<http.MultipartFile> files,
    bool auth = true,
  }) {
    final uri = _uri(path);
    return _send(
      () async {
        final request = http.MultipartRequest('POST', uri);
        final headers = await _headers(auth: auth);
        headers.remove('Content-Type');
        request.headers.addAll(headers);
        if (fields != null) {
          request.fields.addAll(fields);
        }
        request.files.addAll(files);
        final streamed = await _http.send(request);
        return http.Response.fromStream(streamed);
      },
      auth: auth,
      method: 'POST_MULTIPART',
      uri: uri,
    );
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    required bool auth,
    required String method,
    required Uri uri,
  }) async {
    try {
      final res = await request();
      _logHttp(method, uri, res);
      if (res.statusCode == 401 && auth) {
        authLog('401 received — attempting token refresh');
        final refreshed = await tryRefreshTokens();
        if (refreshed) {
          authLog('Token refresh OK — retrying request');
          final retry = await request();
          _logHttp(method, uri, retry, note: 'retry_after_refresh');
          return _decode(retry);
        }
        authLog('Token refresh failed');
      }
      return _decode(res);
    } catch (e) {
      // Temporary diagnose log — no tokens/secrets.
      // ignore: avoid_print
      print(
        '[API] FAIL $method $uri '
        'type=${e.runtimeType} message=$e '
        'baseUrl=${config.apiBaseUrl}',
      );
      rethrow;
    }
  }

  static void _logHttp(
    String method,
    Uri uri,
    http.Response res, {
    String? note,
  }) {
    final bodyPreview = _safeBodyPreview(res.body);
    // ignore: avoid_print
    print(
      '[API] $method $uri → ${res.statusCode}'
      '${note != null ? ' ($note)' : ''}'
      '${bodyPreview.isEmpty ? '' : ' body=$bodyPreview'}',
    );
  }

  /// Truncated body for logs — strips obvious secret-looking fields.
  static String _safeBodyPreview(String body) {
    if (body.isEmpty) return '';
    var text = body;
    for (final key in [
      'accessToken',
      'refreshToken',
      'token',
      'password',
      'secret',
      'keyId',
      'razorpay',
    ]) {
      text = text.replaceAllMapped(
        RegExp('"$key"\\s*:\\s*"[^"]*"', caseSensitive: false),
        (m) => '"$key":"***"',
      );
    }
    if (text.length > 280) {
      text = '${text.substring(0, 280)}…';
    }
    return text;
  }

  /// Exchange refresh token for a new access/refresh pair.
  Future<bool> tryRefreshTokens() async {
    if (_refreshing) return false;
    final refresh = await session.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      authLog('No refresh token available');
      return false;
    }

    _refreshing = true;
    try {
      final res = await _http.post(
        _uri('/auth/refresh'),
        headers: await _headers(auth: false),
        body: jsonEncode({'refreshToken': refresh}),
      );
      final data = _decode(res);
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final access = map['accessToken']?.toString() ?? '';
      final nextRefresh = map['refreshToken']?.toString() ?? '';
      if (access.isEmpty) {
        authLog('Refresh response missing accessToken');
        return false;
      }
      await session.saveSession(
        accessToken: access,
        refreshToken: nextRefresh.isNotEmpty ? nextRefresh : refresh,
        role: (await session.role) ?? 'user',
        name: await session.userName,
        email: await session.userEmail,
        phone: await session.userPhone,
      );
      authLog('Tokens refreshed and saved');
      return true;
    } catch (e) {
      authLog('Refresh error: $e');
      return false;
    } finally {
      _refreshing = false;
    }
  }

  dynamic _decode(http.Response res) {
    dynamic json;
    try {
      json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      throw ApiException(
        'Invalid server response (${res.statusCode})',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json is Map && json['success'] == false) {
        throw ApiException(
          json['message']?.toString() ?? 'Request failed',
          statusCode: res.statusCode,
          body: json,
        );
      }
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    }
    final message = json is Map
        ? (json['message']?.toString() ?? 'Request failed')
        : 'Request failed (${res.statusCode})';
    final detailsText = _formatValidationDetails(json);
    authLog(
      'API error status=${res.statusCode} message=$message'
      '${detailsText.isEmpty ? '' : ' details=$detailsText'}',
    );
    throw ApiException(
      detailsText.isEmpty ? message : '$message — $detailsText',
      statusCode: res.statusCode,
      body: json,
    );
  }

  static String _formatValidationDetails(dynamic json) {
    if (json is! Map) return '';
    final details = json['details'];
    if (details is! List || details.isEmpty) return '';
    return details.map((entry) {
      if (entry is Map) {
        final field = entry['field'] ?? entry['path'] ?? 'field';
        final msg = entry['message'] ?? entry['msg'] ?? 'invalid';
        return '$field: $msg';
      }
      return entry.toString();
    }).join('; ');
  }
}

/// Persists JWT tokens securely.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _access = 'ce_access_token';
  static const _refresh = 'ce_refresh_token';
  static const _role = 'ce_account_role';
  static const _name = 'ce_user_name';
  static const _email = 'ce_user_email';
  static const _phone = 'ce_user_phone';

  Future<String?> get accessToken => _storage.read(key: _access);
  Future<String?> get refreshToken => _storage.read(key: _refresh);
  Future<String?> get role => _storage.read(key: _role);
  Future<String?> get userName => _storage.read(key: _name);
  Future<String?> get userEmail => _storage.read(key: _email);
  Future<String?> get userPhone => _storage.read(key: _phone);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    String? name,
    String? email,
    String? phone,
  }) async {
    if (accessToken.isEmpty) {
      throw ApiException('Login succeeded but accessToken was empty');
    }
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    await _storage.write(key: _role, value: role);
    if (name != null) await _storage.write(key: _name, value: name);
    if (email != null) await _storage.write(key: _email, value: email);
    if (phone != null) await _storage.write(key: _phone, value: phone);

    final loaded = await this.accessToken;
    authLog(
      'Token saved (accessLen=${accessToken.length}, '
      'refreshLen=${refreshToken.length}, role=$role, '
      'reloadOk=${loaded == accessToken})',
    );
  }

  Future<void> clear() async {
    authLog('Clearing session storage');
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _role);
    await _storage.delete(key: _name);
    await _storage.delete(key: _email);
    await _storage.delete(key: _phone);
  }

  Future<bool> get hasSession async =>
      (await accessToken)?.isNotEmpty == true;
}
