import 'package:equatable/equatable.dart';

import 'tenant_membership.dart';

class CentralLoginResult extends Equatable {
  const CentralLoginResult({
    required this.accessToken,
    required this.userId,
    this.userEmail,
    required this.tenants,
  });

  final String accessToken;
  final String userId;
  final String? userEmail;
  final List<TenantMembership> tenants;

  @override
  List<Object?> get props => [accessToken, userId, userEmail, tenants];
}

