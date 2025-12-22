import '../../../../core/network/auth_api.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api}) : _api = api;

  final AuthApi _api;

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

