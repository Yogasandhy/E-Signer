import '../../domain/entities/stored_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/session_local_data_source.dart';

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl({required SessionLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final SessionLocalDataSource _localDataSource;

  @override
  Future<StoredSession> load() async {
    final accessToken = (await _localDataSource.getAccessToken())?.trim();
    final tenant = (await _localDataSource.getTenant())?.trim();
    final userId = (await _localDataSource.getUserId())?.trim();
    final userEmail = (await _localDataSource.getUserEmail())?.trim();

    return StoredSession(
      accessToken: (accessToken ?? '').isEmpty ? null : accessToken,
      tenant: (tenant ?? '').isEmpty ? null : tenant,
      userId: (userId ?? '').isEmpty ? null : userId,
      userEmail: (userEmail ?? '').isEmpty ? null : userEmail,
    );
  }

  @override
  Future<void> save({
    required String accessToken,
    required String tenant,
    required String userId,
    required String userEmail,
  }) {
    return _localDataSource.setSession(
      accessToken: accessToken.trim(),
      tenant: tenant.trim(),
      userId: userId.trim(),
      userEmail: userEmail.trim(),
    );
  }

  @override
  Future<void> clear({bool keepTenant = true}) {
    return _localDataSource.clearSession(keepTenant: keepTenant);
  }

  @override
  Future<String?> getLastTenant() async {
    final tenant = (await _localDataSource.getTenant())?.trim();
    return (tenant == null || tenant.isEmpty) ? null : tenant;
  }

  @override
  Future<void> setLastTenant(String tenant) {
    final t = tenant.trim();
    if (t.isEmpty) return Future.value();
    return _localDataSource.setLastTenant(t);
  }
}

