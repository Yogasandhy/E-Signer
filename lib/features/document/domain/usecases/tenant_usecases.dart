import '../entities/tenant_info.dart';
import '../repositories/tenant_repository.dart';

class TenantUseCases {
  TenantUseCases(this._repository);

  final TenantRepository _repository;

  Future<TenantInfo> getPublicInfo({required String tenant}) {
    return _repository.getPublicInfo(tenant: tenant);
  }
}

