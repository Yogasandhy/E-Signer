import '../entities/tenant_info.dart';

abstract class TenantRepository {
  Future<TenantInfo> getPublicInfo({required String tenant});
}

