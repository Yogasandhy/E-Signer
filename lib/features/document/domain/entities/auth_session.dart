import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.tenant,
    required this.userId,
    this.tenantSlug,
  });

  final String accessToken;

  /// Tenant identifier used in path-based tenancy (`/{tenant}/api/...`).
  ///
  /// Can be a slug or a tenantId (backend supports both).
  final String tenant;

  final String userId;

  /// Optional tenant slug returned by Central register endpoint.
  final String? tenantSlug;

  @override
  List<Object?> get props => [accessToken, tenant, userId, tenantSlug];
}

