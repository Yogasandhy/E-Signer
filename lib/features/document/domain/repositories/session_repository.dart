import '../entities/stored_session.dart';

abstract class SessionRepository {
  Future<StoredSession> load();

  Future<void> save({
    required String accessToken,
    required String tenant,
    required String userId,
    required String userEmail,
  });

  Future<void> clear({bool keepTenant = true});

  Future<String?> getLastTenant();

  Future<void> setLastTenant(String tenant);
}

