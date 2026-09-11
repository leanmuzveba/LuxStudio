import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thin HTTP client for the LuxStudio backend — the only place the Flutter
/// client talks to a server. Holds no secrets: the Gemini API key and the
/// FFmpeg binary live entirely on the backend (see backend/README.md).
///
/// Base URL defaults to the local dev backend; override at build/run time
/// with `--dart-define=API_BASE_URL=https://your-backend.example.com`.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = httpClient ?? http.Client();

  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(_uri(path));
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(String path) async {
    final response = await _client.get(_uri(path));
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FormatException('Expected a JSON array, got: $decoded');
    }
    return decoded;
  }

  Future<void> delete(String path) async {
    final response = await _client.delete(_uri(path));
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeObject(response);
  }

  /// Multipart upload — fine for a small file (e.g. a church logo), held
  /// in memory as one buffer. A large video should go through
  /// `chunked_upload.dart` instead (see its doc for why).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    if (fields != null) request.fields.addAll(fields);
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decodeObject(response);
  }

  /// PUTs a raw chunk of bytes — the building block `chunked_upload.dart`
  /// uses to stream a large file to the backend in small pieces instead of
  /// one big in-memory buffer.
  Future<Map<String, dynamic>> putBytes(String path, Uint8List bytes) async {
    final response = await _client.put(
      _uri(path),
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    return _decodeObject(response);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _client.get(_uri(path));
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected a JSON object, got: $decoded');
    }
    return decoded;
  }

  void close() => _client.close();
}

/// Thrown when the backend responds with a 4xx/5xx status. [body] is the
/// raw response text (usually a FastAPI `{"detail": "..."}` JSON error).
class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
