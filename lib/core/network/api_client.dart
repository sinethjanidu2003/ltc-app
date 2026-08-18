import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/env.dart';
import 'api_exception.dart';

/// Thin HTTP wrapper for the LTC `/api/*` backend.
///
/// Every request includes `X-API-Key`. Authenticated routes also send
/// `Authorization: Bearer <token>` when [setAuthToken] has been called.
class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  String? get authToken => _authToken;

  Future<Map<String, dynamic>> get(String path) async {
    final decoded = await _send('GET', path);
    return _asMap(decoded);
  }

  Future<List<dynamic>> getList(String path) async {
    final decoded = await _send('GET', path);
    return _asList(decoded);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final decoded = await _send('POST', path, body: body);
    return _asMap(decoded);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final decoded = await _send('PUT', path, body: body);
    return _asMap(decoded);
  }

  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-API-Key': AppEnv.apiKey,
      if (_authToken != null && _authToken!.isNotEmpty)
        'Authorization': 'Bearer $_authToken',
      if (body != null) 'Content-Type': 'application/json',
    };

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers);
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'PUT':
          response = await _http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        case 'DELETE':
          response = await _http.delete(uri, headers: headers);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } catch (error) {
      if (error is ApiException) rethrow;
      _logApiError(
        method: method,
        uri: uri,
        requestBody: body,
        statusCode: null,
        responseBody: error.toString(),
      );
      throw ApiException(
        message:
            'Unable to reach the server. Check your connection and API_BASE_URL.',
        body: error.toString(),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logApiError(
        method: method,
        uri: uri,
        requestBody: body,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _decode(response);
  }

  void _logApiError({
    required String method,
    required Uri uri,
    required Map<String, dynamic>? requestBody,
    required int? statusCode,
    required String responseBody,
  }) {
    final buffer = StringBuffer()
      ..writeln('========== API ERROR ==========')
      ..writeln('$method $uri')
      ..writeln('status: ${statusCode ?? 'network/unreachable'}');
    if (requestBody != null) {
      buffer.writeln('request: ${jsonEncode(requestBody)}');
    }
    buffer
      ..writeln(
        'response: ${responseBody.isEmpty ? '(empty)' : responseBody}',
      )
      ..writeln('================================');
    debugPrint(buffer.toString());
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final raw = response.body;

    if (status == 204 || raw.isEmpty) {
      if (status >= 200 && status < 300) return <String, dynamic>{};
      throw ApiException(
        message: 'Request failed with status $status',
        statusCode: status,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = {'message': raw};
    }

    if (status >= 200 && status < 300) {
      return decoded;
    }

    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'message': decoded.toString()};

    throw ApiException(
      message: _extractMessage(map) ?? 'Request failed with status $status',
      statusCode: status,
      body: raw,
    );
  }

  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }

  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List<dynamic>;
    }
    throw ApiException(
      message: 'Expected a JSON list from the API.',
      body: decoded?.toString(),
    );
  }

  String? _extractMessage(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;

    final error = json['error'];
    if (error is String && error.isNotEmpty) return error;

    final errors = json['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
      return first.toString();
    }

    return null;
  }

  void dispose() => _http.close();
}
