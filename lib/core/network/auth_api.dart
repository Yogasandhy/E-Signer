import 'dart:convert';
import 'dart:io';

import '../errors/api_exception.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<CentralLoginResponse> loginCentral({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) {
      throw const ApiException('Email is required.');
    }
    if (password.isEmpty) {
      throw const ApiException('Password is required.');
    }

    final body = await _apiClient.postJson(
      uri: _apiClient.apiUri(path: 'api/auth/login'),
      jsonBody: <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
      defaultErrorMessage: 'Login failed.',
    );

    return CentralLoginResponse.fromJsonString(body);
  }

  Future<SelectTenantResponse> selectTenant({
    required String centralAccessToken,
    required String tenant,
  }) async {
    final token = centralAccessToken.trim();
    if (token.isEmpty) {
      throw const ApiException('Central access token is required.');
    }

    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }

    final body = await _apiClient.postJson(
      uri: _apiClient.apiUri(path: 'api/auth/select-tenant'),
      jsonBody: <String, dynamic>{
        'tenant': t,
      },
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $token',
      },
      defaultErrorMessage: 'Select tenant failed.',
    );

    return SelectTenantResponse.fromJsonString(body);
  }

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
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  }) async {
    final n = tenantName.trim();
    if (n.isEmpty) {
      throw const ApiException('Tenant name is required.');
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

    final resolvedTenantSlug = tenantSlug?.trim();
    final resolvedRole = role?.trim();

    final payload = <String, dynamic>{
      'tenantName': n,
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    if (resolvedTenantSlug != null && resolvedTenantSlug.isNotEmpty) {
      payload['tenantSlug'] = resolvedTenantSlug;
    }
    if (resolvedRole != null && resolvedRole.isNotEmpty) {
      payload['role'] = resolvedRole;
    }

    final body = await _apiClient.postJson(
      uri: _apiClient.apiUri(path: 'api/tenants/register'),
      jsonBody: payload,
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
    final tenantSlug = map['tenantSlug']?.toString().trim();
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
      tenantSlug: (tenantSlug == null || tenantSlug.isEmpty) ? null : tenantSlug,
      userId: userId,
    );
  }
}

class AuthLoginResponse {
  const AuthLoginResponse({
    required this.accessToken,
    required this.tenantId,
    this.tenantSlug,
    required this.userId,
  });

  final String accessToken;
  final String tenantId;
  final String? tenantSlug;
  final String userId;
}

class CentralLoginResponse {
  const CentralLoginResponse({
    required this.accessToken,
    required this.user,
    required this.tenants,
  });

  final String accessToken;
  final CentralUser user;
  final List<CentralTenantMembership> tenants;

  static CentralLoginResponse fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ApiException('Invalid login response.');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final accessToken = map['accessToken']?.toString().trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('Auth response missing accessToken.');
    }

    final rawUser = map['user'];
    if (rawUser is! Map) {
      throw const ApiException('Auth response missing user object.');
    }
    final user = CentralUser.fromJsonMap(rawUser);

    final rawTenants = map['tenants'];
    final tenants = <CentralTenantMembership>[];
    if (rawTenants is List) {
      for (final entry in rawTenants) {
        if (entry is Map) {
          tenants.add(CentralTenantMembership.fromJsonMap(entry));
        }
      }
    }

    return CentralLoginResponse(
      accessToken: accessToken,
      user: user,
      tenants: tenants,
    );
  }
}

class CentralUser {
  const CentralUser({
    required this.userId,
    this.name,
    this.email,
    this.isSuperadmin,
  });

  final String userId;
  final String? name;
  final String? email;
  final bool? isSuperadmin;

  static CentralUser fromJsonMap(Map raw) {
    final user = raw.map((k, v) => MapEntry(k.toString(), v));

    final userId = user['userId']?.toString().trim();
    if (userId == null || userId.isEmpty) {
      throw const ApiException('Auth response missing userId.');
    }

    final name = user['name']?.toString().trim();
    final email = user['email']?.toString().trim();

    bool? isSuperadmin;
    final rawIsSuperadmin = user['isSuperadmin'];
    if (rawIsSuperadmin is bool) {
      isSuperadmin = rawIsSuperadmin;
    } else if (rawIsSuperadmin != null) {
      final parsed = rawIsSuperadmin.toString().trim().toLowerCase();
      if (parsed == 'true') isSuperadmin = true;
      if (parsed == 'false') isSuperadmin = false;
    }

    return CentralUser(
      userId: userId,
      name: name?.isEmpty == true ? null : name,
      email: email?.isEmpty == true ? null : email,
      isSuperadmin: isSuperadmin,
    );
  }
}

class CentralTenantMembership {
  const CentralTenantMembership({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
    this.isOwner,
  });

  final String id;
  final String name;
  final String slug;
  final String? role;
  final bool? isOwner;

  static CentralTenantMembership fromJsonMap(Map raw) {
    final tenant = raw.map((k, v) => MapEntry(k.toString(), v));

    final id = tenant['id']?.toString().trim();
    final name = tenant['name']?.toString().trim();
    final slug = tenant['slug']?.toString().trim();

    if (id == null || id.isEmpty) {
      throw const ApiException('Tenant membership missing id.');
    }
    if (name == null || name.isEmpty) {
      throw const ApiException('Tenant membership missing name.');
    }
    if (slug == null || slug.isEmpty) {
      throw const ApiException('Tenant membership missing slug.');
    }

    final role = tenant['role']?.toString().trim();

    bool? isOwner;
    final rawIsOwner = tenant['isOwner'];
    if (rawIsOwner is bool) {
      isOwner = rawIsOwner;
    } else if (rawIsOwner != null) {
      final parsed = rawIsOwner.toString().trim().toLowerCase();
      if (parsed == 'true') isOwner = true;
      if (parsed == 'false') isOwner = false;
    }

    return CentralTenantMembership(
      id: id,
      name: name,
      slug: slug,
      role: role?.isEmpty == true ? null : role,
      isOwner: isOwner,
    );
  }
}

class SelectTenantResponse {
  const SelectTenantResponse({
    required this.accessToken,
    required this.tenant,
  });

  final String accessToken;
  final CentralTenantMembership tenant;

  static SelectTenantResponse fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ApiException('Invalid select-tenant response.');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final accessToken = map['accessToken']?.toString().trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException('Select tenant response missing accessToken.');
    }

    final rawTenant = map['tenant'];
    if (rawTenant is! Map) {
      throw const ApiException('Select tenant response missing tenant object.');
    }

    return SelectTenantResponse(
      accessToken: accessToken,
      tenant: CentralTenantMembership.fromJsonMap(rawTenant),
    );
  }
}
