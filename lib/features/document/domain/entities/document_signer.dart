import 'package:equatable/equatable.dart';

class DocumentSigner extends Equatable {
  const DocumentSigner({
    required this.index,
    required this.tenantId,
    required this.userId,
    this.name,
    this.email,
    this.role,
    this.signedAtIso = '',
  });

  final int index;
  final String tenantId;
  final String userId;
  final String? name;
  final String? email;
  final String? role;
  final String signedAtIso;

  @override
  List<Object?> get props => [index, tenantId, userId, name, email, role, signedAtIso];
}
