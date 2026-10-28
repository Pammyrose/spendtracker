import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudApiException implements Exception {
  const CloudApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CloudBackup {
  const CloudBackup(this.revision, this.data, this.updatedAt);
  final int revision;
  final Map<String, dynamic>? data;
  final DateTime? updatedAt;
  factory CloudBackup.fromJson(Map<String, dynamic> value) {
    if (value['revision'] is! int ||
        value['revision'] < 0 ||
        value['data'] != null && value['data'] is! Map<String, dynamic> ||
        value['updatedAt'] != null && value['updatedAt'] is! String) {
      throw const CloudApiException('The server returned an invalid backup.');
    }
    final data = value['data'] as Map<String, dynamic>?;
    if (data != null &&
        (data['version'] != 1 ||
            data['expenses'] is! List ||
            data['incomes'] is! List ||
            data['bills'] is! List)) {
      throw const CloudApiException(
        'The server returned an incompatible app backup.',
      );
    }
    return CloudBackup(
      value['revision'],
      value['data'],
      DateTime.tryParse(value['updatedAt'] as String? ?? ''),
    );
  }
}

// Only the API URL leaves configuration. Database credentials stay on Node.js.
// Session tokens live in memory and are excluded from app backups.
class CloudApi extends ChangeNotifier {
  CloudApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? _token, email, name;
  String get displayName => name != null && name!.trim().isNotEmpty
      ? name!.trim()
      : email?.split('@').first ?? 'there';
  CloudBackup? latest;
  String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  bool get signedIn => _token != null;
  String get suggestedUrl => baseUrl.isNotEmpty
      ? baseUrl
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000'
      : 'http://127.0.0.1:3000';

  void configure(String url) {
    final uri = Uri.tryParse(url.trim());
    final host = uri?.host ?? '';
    final octets = host.split('.').map(int.tryParse).toList();
    final ipv4 =
        octets.length == 4 &&
        octets.every((part) => part != null && part >= 0 && part <= 255);
    final privateHost =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        ipv4 &&
            (octets[0] == 10 ||
                octets[0] == 192 && octets[1] == 168 ||
                octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '' && uri.path != '/' ||
        uri.scheme != 'https' &&
            !(uri.scheme == 'http' && !kReleaseMode && privateHost)) {
      throw const CloudApiException(
        'Use an HTTPS API URL, or a local HTTP address in debug mode.',
      );
    }
    final configured = uri
        .replace(path: '')
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
    if (configured != baseUrl) {
      _token = null;
      email = null;
      name = null;
      latest = null;
    }
    baseUrl = configured;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final requestToken = _token;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers.addAll(headers)
        ..followRedirects = false;
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 10)),
      ).timeout(const Duration(seconds: 15));
      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 &&
            _token == requestToken &&
            !path.startsWith('/auth/')) {
          _token = null;
          email = null;
          name = null;
          latest = null;
          notifyListeners();
        }
        throw CloudApiException(
          payload['error'] is String
              ? payload['error']
              : 'The server could not complete that request.',
        );
      }
      return payload;
    } on CloudApiException {
      rethrow;
    } on TimeoutException {
      throw const CloudApiException(
        'The server timed out. Check the server backup before retrying a save.',
      );
    } on FormatException {
      throw const CloudApiException(
        'The server returned an unexpected response. Check the API URL.',
      );
    } on http.ClientException {
      throw const CloudApiException(
        'Cannot reach the API. Start Node.js and XAMPP MySQL, then check the server URL.',
      );
    }
  }

  Future<void> authenticate(
    String url,
    String emailAddress,
    String password, {
    required bool register,
    String? name,
  }) async {
    configure(url);
    final response = await _request(
      'POST',
      register ? '/auth/register' : '/auth/login',
      {
        'email': emailAddress.trim(),
        'password': password,
        if (register) 'name': name?.trim() ?? '',
      },
    );
    if (response['token'] is! String || response['email'] is! String) {
      throw const CloudApiException('Invalid sign-in response.');
    }
    _token = response['token'];
    email = response['email'];
    this.name = response['name'] is String ? response['name'] : null;
    latest = null;
    notifyListeners();
    await refresh();
  }

  Future<CloudBackup> refresh() async {
    final token = _token;
    final remote = CloudBackup.fromJson(await _request('GET', '/backup'));
    if (token != _token) {
      throw const CloudApiException('The signed-in account changed.');
    }
    latest = remote;
    notifyListeners();
    return latest!;
  }

  Future<void> updateProfileName(String value) async {
    final response = await _request('PATCH', '/profile', {
      'name': value.trim(),
    });
    if (response['name'] is! String ||
        (response['name'] as String).trim().isEmpty ||
        response['email'] != email) {
      throw const CloudApiException('The server returned an invalid profile.');
    }
    name = response['name'];
    notifyListeners();
  }

  Future<void> upload(String document, {int? revision}) async {
    if (latest == null) {
      throw const CloudApiException('Refresh the server backup before saving.');
    }
    final data = jsonDecode(document) as Map<String, dynamic>;
    final token = _token;
    final result = await _request('PUT', '/backup', {
      'revision': revision ?? latest!.revision,
      'data': data,
    });
    if (token != _token) {
      throw const CloudApiException('The signed-in account changed.');
    }
    if (result['revision'] is! int) {
      throw const CloudApiException(
        'Invalid save response. Refresh to check the server backup.',
      );
    }
    latest = CloudBackup(result['revision'], data, DateTime.now());
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if (signedIn) await _request('DELETE', '/auth/session');
    } finally {
      _token = null;
      email = null;
      name = null;
      latest = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
