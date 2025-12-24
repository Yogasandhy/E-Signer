import '../../../../core/network/auth_api.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/central_login_result.dart';
import '../../domain/entities/select_tenant_result.dart';
import '../../domain/entities/tenant_membership.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api}) : _api = api;

  final AuthApi _api;

  @override
  Future<CentralLoginResult> loginCentral({
    required String email,
    required String password,
  }) async {
    final resp = await _api.loginCentral(
      email: email,
      password: password,
    );

    return CentralLoginResult(
      accessToken: resp.accessToken,
      userId: resp.user.userId,
      userEmail: resp.user.email,
      tenants: resp.tenants
          .map(
            (t) => TenantMembership(
              id: t.id,
              name: t.name,
              slug: t.slug,
              role: t.role,
              isOwner: t.isOwner,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<SelectTenantResult> selectTenant({
    required String centralAccessToken,
    required String tenant,
  }) async {
    final resp = await _api.selectTenant(
      centralAccessToken: centralAccessToken,
      tenant: tenant,
    );

    return SelectTenantResult(
      accessToken: resp.accessToken,
      tenant: TenantMembership(
        id: resp.tenant.id,
        name: resp.tenant.name,
        slug: resp.tenant.slug,
        role: resp.tenant.role,
        isOwner: resp.tenant.isOwner,
      ),
    );
  }

  @override
  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) async {
    final resp = await _api.login(
      tenant: tenant,
      email: email,
      password: password,
      deviceName: deviceName,
    );

    return AuthSession(
      accessToken: resp.accessToken,
      tenant: resp.tenantId,
      userId: resp.userId,
      tenantSlug: resp.tenantSlug,
    );
  }

  @override
  Future<AuthSession> registerTenant({
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  }) async {
    final resp = await _api.register(
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      role: role,
    );

    return AuthSession(
      accessToken: resp.accessToken,
      tenant: resp.tenantId,
      userId: resp.userId,
      tenantSlug: resp.tenantSlug,
    );
  }

  @override
  Future<void> me({
    required String tenant,
    required String accessToken,
  }) {
    return _api.me(tenant: tenant, accessToken: accessToken);
  }
}
