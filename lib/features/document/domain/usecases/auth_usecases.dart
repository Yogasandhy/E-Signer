import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';
import '../repositories/session_repository.dart';

class AuthUseCases {
  AuthUseCases({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
  })  : _authRepository = authRepository,
        _sessionRepository = sessionRepository;

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;

  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) async {
    final session = await _authRepository.login(
      tenant: tenant,
      email: email,
      password: password,
      deviceName: deviceName,
    );

    await _sessionRepository.save(
      accessToken: session.accessToken,
      tenant: tenant,
      userId: session.userId,
      userEmail: email,
    );
    await _sessionRepository.setLastTenant(tenant);

    return session;
  }

  Future<AuthSession> registerTenant({
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  }) async {
    final session = await _authRepository.registerTenant(
      tenantName: tenantName,
      tenantSlug: tenantSlug,
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      role: role,
    );

    final resolvedTenant =
        (session.tenantSlug ?? '').trim().isNotEmpty ? session.tenantSlug!.trim() : session.tenant.trim();

    await _sessionRepository.save(
      accessToken: session.accessToken,
      tenant: resolvedTenant,
      userId: session.userId,
      userEmail: email,
    );
    await _sessionRepository.setLastTenant(resolvedTenant);

    return session;
  }

  Future<void> me({
    required String tenant,
    required String accessToken,
  }) {
    return _authRepository.me(
      tenant: tenant,
      accessToken: accessToken,
    );
  }
}

