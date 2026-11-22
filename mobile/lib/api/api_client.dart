import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// JSON over HTTP for the CrewMatch API: base URL, bearer token and errors.
///
/// Every response body is a JSON object (or empty for `204`), so each call
/// returns a map. Failures throw [ApiException].
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  /// The JWT from sign-in, sent as `Authorization: Bearer <token>`.
  String? token;

  /// Called when a signed-in request is rejected with 401 (expired token or
  /// deleted account), so the app can send the user back to sign in.
  void Function()? onUnauthorized;

  /// A server path such as `/api/photos/…` as a full URL on the API's host.
  String resolve(String path) => path.startsWith('http') ? path : Uri.parse(baseUrl).resolve(path).toString();

  Future<Map<String, dynamic>> get(String path) => send('GET', path);

  /// [timeout] overrides the default for slow calls such as uploads.
  Future<Map<String, dynamic>> post(String path, [Map<String, Object?>? body, Duration? timeout]) =>
      send('POST', path, body ?? const {}, timeout);

  Future<Map<String, dynamic>> put(String path, Map<String, Object?> body) =>
      send('PUT', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, Object?> body) =>
      send('PATCH', path, body);

  Future<Map<String, dynamic>> delete(String path) => send('DELETE', path);

  /// Raw bytes from a signed-in GET, e.g. a document from the crew chat.
  /// [path] may include the `/api` prefix, as file URLs from the API do.
  Future<Uint8List> getBytes(String path) async {
    final url = path.startsWith('/api/') ? resolve(path) : '$baseUrl$path';
    final request = http.Request('GET', Uri.parse(url));
    final token = this.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await _http.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 60));
    } on Exception {
      throw ApiException(0, "Can't reach the server at $baseUrl. Is the API running?");
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return response.bodyBytes;
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException.fromBody(response.statusCode, _decode(response));
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path, [
    Map<String, Object?>? body,
    Duration? timeout,
  ]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Accept'] = 'application/json';
    final token = this.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout ?? this.timeout);
    } on Exception {
      throw ApiException(
        0,
        "Can't reach the server at $baseUrl. Is the API running?",
      );
    }

    final data = _decode(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return data ?? const {};

    if (status == 401 && token != null) onUnauthorized?.call();
    throw ApiException.fromBody(status, data);
  }

  static Map<String, dynamic>? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  void close() => _http.close();
}
