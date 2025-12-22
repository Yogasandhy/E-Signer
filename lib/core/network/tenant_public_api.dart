import 'dart:convert';

import '../errors/api_exception.dart';
import 'api_client.dart';

class TenantPublicApi {
  TenantPublicApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Map<String, TenantInfo> _cache = <String, TenantInfo>{};

  Future<TenantInfo> getInfo({required String tenant}) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }

    final cached = _cache[t];
    if (cached != null) return cached;

    final body = await _apiClient.getJson(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/public/info'),
      defaultErrorMessage: 'Failed to load tenant info.',
    );

    final info = TenantInfo.fromJsonString(body);
    _cache[t] = info;
    _cache[info.id] = info;
    _cache[info.slug] = info;
    return info;
  }
}

class TenantInfo {
  const TenantInfo({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  static TenantInfo fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ApiException('Invalid tenant info response.');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final rawTenant = map['tenant'];
    if (rawTenant is! Map) {
      throw const ApiException('Tenant info response missing tenant object.');
    }

    final tenant = rawTenant.map((k, v) => MapEntry(k.toString(), v));
    final id = tenant['id']?.toString().trim();
    final name = tenant['name']?.toString().trim();
    final slug = tenant['slug']?.toString().trim();

    if (id == null || id.isEmpty) {
      throw const ApiException('Tenant info missing id.');
    }
    if (name == null || name.isEmpty) {
      throw const ApiException('Tenant info missing name.');
    }
    if (slug == null || slug.isEmpty) {
      throw const ApiException('Tenant info missing slug.');
    }

    return TenantInfo(id: id, name: name, slug: slug);
  }
}

