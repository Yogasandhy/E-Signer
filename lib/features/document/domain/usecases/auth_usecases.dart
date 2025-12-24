import '../entities/auth_session.dart';
import '../entities/central_login_result.dart';
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

  Future<CentralLoginResult> loginCentral({
    required String email,
    required String password,
  }) {
    return _authRepository.loginCentral(
      email: email,
      password: password,
    );
  }

  Future<AuthSession> selectTenant({
    required String centralAccessToken,
    required String tenant,
    required String userId,
    required String userEmail,
  }) async {
    final selection = await _authRepository.selectTenant(
      centralAccessToken: centralAccessToken,
      tenant: tenant,
    );

    final role = (selection.tenant.role ?? '').trim().toLowerCase();
    if (role != 'user') {
      throw Exception(
        'Role "${selection.tenant.role ?? '-'}" tidak didukung di aplikasi ini. Gunakan akun role user.',
      );
    }

    final resolvedTenant = selection.tenant.slug.trim();

    await _sessionRepository.save(
      accessToken: selection.accessToken,
      tenant: resolvedTenant,
      userId: userId,
      userEmail: userEmail,
    );
    await _sessionRepository.setLastTenant(resolvedTenant);

    return AuthSession(
      accessToken: selection.accessToken,
      tenant: resolvedTenant,
      userId: userId,
      tenantSlug: selection.tenant.slug,
    );
  }

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
