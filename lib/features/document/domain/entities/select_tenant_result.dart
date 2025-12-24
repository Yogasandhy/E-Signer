import 'package:equatable/equatable.dart';

import 'tenant_membership.dart';

class SelectTenantResult extends Equatable {
  const SelectTenantResult({
    required this.accessToken,
    required this.tenant,
  });

  final String accessToken;
  final TenantMembership tenant;

  @override
  List<Object?> get props => [accessToken, tenant];
}

