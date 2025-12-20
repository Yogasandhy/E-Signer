import 'dart:convert';
import 'dart:io';

import '../errors/api_exception.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthLoginResponse> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }

    final body = await _apiClient.postJson(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/auth/login'),
      jsonBody: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'deviceName': deviceName,
      },
      defaultErrorMessage: 'Login failed.',
    );

    return _parseAuthResponse(body, fallbackMessage: 'Invalid login response.');
  }

  Future<AuthLoginResponse> register({
    required String tenant,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String deviceName = 'android',
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }
    if (name.trim().isEmpty) {
      throw const ApiException('Name is required.');
    }
    if (email.trim().isEmpty) {
      throw const ApiException('Email is required.');
    }
    if (password.isEmpty) {
      throw const ApiException('Password is required.');
    }
    if (passwordConfirmation.isEmpty) {
      throw const ApiException('Password confirmation is required.');
    }

    final body = await _apiClient.postJson(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/auth/register'),
      jsonBody: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'deviceName': deviceName,
      },
      defaultErrorMessage: 'Register failed.',
    );

    return _parseAuthResponse(
      body,
      fallbackMessage: 'Invalid register response.',
    );
  }

  Future<void> me({
    required String tenant,
    required String accessToken,
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }

    await _apiClient.getJson(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/auth/me'),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${accessToken.trim()}',
      },
      defaultErrorMessage: 'Unauthorized.',
    );
  }

  AuthLoginResponse _parseAuthResponse(
    String body, {
    required String fallbackMessage,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw ApiException(fallbackMessage);
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final accessToken = map['accessToken']?.toString().trim();
    final tenantId = map['tenantId']?.toString().trim();
    final userId = map['userId']?.toString().trim();

    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('Auth response missing accessToken.');
    }
    if (tenantId == null || tenantId.isEmpty) {
      throw const ApiException('Auth response missing tenantId.');
    }
    if (userId == null || userId.isEmpty) {
      throw const ApiException('Auth response missing userId.');
    }

    return AuthLoginResponse(
      accessToken: accessToken,
      tenantId: tenantId,
      userId: userId,
    );
  }
}

class AuthLoginResponse {
  const AuthLoginResponse({
    required this.accessToken,
    required this.tenantId,
    required this.userId,
  });

  final String accessToken;
  final String tenantId;
  final String userId;
}
