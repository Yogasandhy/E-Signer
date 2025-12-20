import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../errors/api_exception.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Uri tenantUri({
    required String tenant,
    required String path,
  }) {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }

    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$t/$p');
  }

  Uri resolveUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) {
      throw const ApiException('URL is empty.');
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw const ApiException('Invalid URL.');
    }

    return parsed.isAbsolute ? parsed : Uri.parse('$baseUrl/').resolveUri(parsed);
  }

  Future<String> getJson({
    required Uri uri,
    Map<String, String>? headers,
    String defaultErrorMessage = 'Request failed.',
  }) async {
    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    _applyHeaders(request, headers);

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (!_isSuccess(response.statusCode)) {
      throw ApiException(
        _extractErrorMessage(body) ?? defaultErrorMessage,
        statusCode: response.statusCode,
        details: body,
      );
    }
    return body;
  }

  Future<String> postJson({
    required Uri uri,
    required Map<String, dynamic> jsonBody,
    Map<String, String>? headers,
    String defaultErrorMessage = 'Request failed.',
  }) async {
    final request = await _httpClient.postUrl(uri);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.contentTypeHeader, 'application/json');
    _applyHeaders(request, headers);

    request.add(utf8.encode(jsonEncode(jsonBody)));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (!_isSuccess(response.statusCode)) {
      throw ApiException(
        _extractErrorMessage(body) ?? defaultErrorMessage,
        statusCode: response.statusCode,
        details: body,
      );
    }
    return body;
  }

  Future<String> postMultipart({
    required Uri uri,
    required Map<String, String> fields,
    required List<ApiMultipartFile> files,
    Map<String, String>? headers,
    String defaultErrorMessage = 'Request failed.',
  }) async {
    if (files.isEmpty) {
      throw const ApiException('Multipart request requires at least 1 file.');
    }

    final boundary = _newBoundary();
    final request = await _httpClient.postUrl(uri);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
    _applyHeaders(request, headers);

    final parts = <_MultipartPart>[];
    for (final file in files) {
      parts.add(_MultipartPart.file(file));
    }
    for (final entry in fields.entries) {
      parts.add(_MultipartPart.field(name: entry.key, value: entry.value));
    }

    request.contentLength = await _computeMultipartLength(
      boundary: boundary,
      parts: parts,
    );

    for (final part in parts) {
      request.add(utf8.encode(part.header(boundary)));
      if (part.file != null) {
        await request.addStream(part.file!.file.openRead());
        request.add(const [13, 10]); // \r\n
      } else {
        request.add(utf8.encode(part.value ?? ''));
        request.add(const [13, 10]); // \r\n
      }
    }
    request.add(utf8.encode('--$boundary--\r\n'));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (!_isSuccess(response.statusCode)) {
      throw ApiException(
        _extractErrorMessage(body) ?? defaultErrorMessage,
        statusCode: response.statusCode,
        details: body,
      );
    }
    return body;
  }

  Future<Uint8List> getBytes({
    required Uri uri,
    Map<String, String>? headers,
    String defaultErrorMessage = 'Request failed.',
  }) async {
    final request = await _httpClient.getUrl(uri);
    _applyHeaders(request, headers);

    final response = await request.close();
    if (_isSuccess(response.statusCode)) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    final body = await utf8.decodeStream(response);
    throw ApiException(
      _extractErrorMessage(body) ?? defaultErrorMessage,
      statusCode: response.statusCode,
      details: body,
    );
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  void _applyHeaders(HttpClientRequest request, Map<String, String>? headers) {
    if (headers == null) return;
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }

  String _newBoundary() =>
      '----ttd_form_${DateTime.now().microsecondsSinceEpoch}';

  Future<int> _computeMultipartLength({
    required String boundary,
    required List<_MultipartPart> parts,
  }) async {
    var length = 0;
    for (final part in parts) {
      length += utf8.encode(part.header(boundary)).length;
      if (part.file != null) {
        length += await part.file!.file.length();
        length += 2; // \r\n after file bytes
      } else {
        length += utf8.encode(part.value ?? '').length;
        length += 2; // \r\n after field value
      }
    }
    length += utf8.encode('--$boundary--\r\n').length;
    return length;
  }

  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry(k.toString(), v));
        final message = map['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
        final error = map['error']?.toString().trim();
        if (error != null && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return null;
  }
}

class ApiMultipartFile {
  const ApiMultipartFile({
    required this.field,
    required this.file,
    required this.contentType,
    this.fileName,
  });

  final String field;
  final File file;
  final String contentType;
  final String? fileName;
}

class _MultipartPart {
  const _MultipartPart._({
    required this.name,
    this.value,
    this.file,
  });

  factory _MultipartPart.field({
    required String name,
    required String value,
  }) {
    return _MultipartPart._(name: name, value: value);
  }

  factory _MultipartPart.file(ApiMultipartFile file) {
    return _MultipartPart._(name: file.field, file: file);
  }

  final String name;
  final String? value;
  final ApiMultipartFile? file;

  String header(String boundary) {
    if (file != null) {
      final resolvedName = (file!.fileName == null || file!.fileName!.isEmpty)
          ? file!.file.uri.pathSegments.lastOrNull ?? 'document.pdf'
          : file!.fileName!;
      return '--$boundary\r\n'
          'Content-Disposition: form-data; name="$name"; filename="$resolvedName"\r\n'
          'Content-Type: ${file!.contentType}\r\n\r\n';
    }

    return '--$boundary\r\n'
        'Content-Disposition: form-data; name="$name"\r\n'
        'Content-Type: text/plain; charset=utf-8\r\n\r\n';
  }
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
