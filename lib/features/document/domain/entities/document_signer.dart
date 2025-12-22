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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'tenantId': tenantId,
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'signedAtIso': signedAtIso,
    };
  }

  static DocumentSigner? fromJson(Object? input) {
    if (input is! Map) return null;
    final json = input.map((k, v) => MapEntry(k.toString(), v));

    final index = (json['index'] is int) ? json['index'] as int : int.tryParse(json['index']?.toString() ?? '');
    final tenantId = json['tenantId']?.toString().trim();
    final userId = json['userId']?.toString().trim();
    final name = json['name']?.toString().trim();
    final email = json['email']?.toString().trim();
    final role = json['role']?.toString().trim();
    final signedAtIso = (json['signedAtIso'] ?? json['signedAt'])?.toString().trim() ?? '';

    if (index == null || index < 1) return null;
    if (tenantId == null || tenantId.isEmpty) return null;
    if (userId == null || userId.isEmpty) return null;

    return DocumentSigner(
      index: index,
      tenantId: tenantId,
      userId: userId,
      name: (name == null || name.isEmpty) ? null : name,
      email: (email == null || email.isEmpty) ? null : email,
      role: (role == null || role.isEmpty) ? null : role,
      signedAtIso: signedAtIso,
    );
  }

  @override
  List<Object?> get props => [index, tenantId, userId, name, email, role, signedAtIso];
}
