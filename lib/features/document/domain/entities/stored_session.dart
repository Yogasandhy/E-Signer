import 'package:equatable/equatable.dart';

class StoredSession extends Equatable {
  const StoredSession({
    this.accessToken,
    this.tenant,
    this.userId,
    this.userEmail,
  });

  final String? accessToken;
  final String? tenant;
  final String? userId;
  final String? userEmail;

  bool get isLoggedIn =>
      (accessToken ?? '').trim().isNotEmpty &&
      (tenant ?? '').trim().isNotEmpty &&
      (userId ?? '').trim().isNotEmpty;

  @override
  List<Object?> get props => [accessToken, tenant, userId, userEmail];
}

