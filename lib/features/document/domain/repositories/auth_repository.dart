import '../entities/auth_session.dart';
import '../entities/central_login_result.dart';
import '../entities/select_tenant_result.dart';

abstract class AuthRepository {
  Future<CentralLoginResult> loginCentral({
    required String email,
    required String password,
  });

  Future<SelectTenantResult> selectTenant({
    required String centralAccessToken,
    required String tenant,
  });

  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  });

  Future<AuthSession> registerTenant({
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  });

  Future<void> me({
    required String tenant,
    required String accessToken,
  });
}
