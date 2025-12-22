import '../entities/auth_session.dart';

abstract class AuthRepository {
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

