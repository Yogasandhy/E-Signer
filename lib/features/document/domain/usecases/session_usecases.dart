import '../entities/stored_session.dart';
import '../repositories/session_repository.dart';

class SessionUseCases {
  SessionUseCases(this._repository);

  final SessionRepository _repository;

  Future<StoredSession> load() => _repository.load();

  Future<void> clear({bool keepTenant = true}) =>
      _repository.clear(keepTenant: keepTenant);

  Future<String?> getLastTenant() => _repository.getLastTenant();

  Future<void> setLastTenant(String tenant) => _repository.setLastTenant(tenant);
}

