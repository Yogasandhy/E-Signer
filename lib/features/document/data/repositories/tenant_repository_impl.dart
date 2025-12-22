import '../../../../core/network/tenant_public_api.dart' as remote;
import '../../domain/entities/tenant_info.dart';
import '../../domain/repositories/tenant_repository.dart';

class TenantRepositoryImpl implements TenantRepository {
  TenantRepositoryImpl({required remote.TenantPublicApi api}) : _api = api;

  final remote.TenantPublicApi _api;

  @override
  Future<TenantInfo> getPublicInfo({required String tenant}) async {
    final info = await _api.getInfo(tenant: tenant);
    return TenantInfo(
      id: info.id,
      name: info.name,
      slug: info.slug,
    );
  }
}

