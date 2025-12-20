import 'package:equatable/equatable.dart';

class DocumentSigner extends Equatable {
  const DocumentSigner({
    required this.index,
    required this.tenantId,
    required this.userId,
    required this.signedAtIso,
    required this.verificationUrl,
  });

  final int index;
  final String tenantId;
  final String userId;
  final String signedAtIso;
  final String verificationUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'tenantId': tenantId,
      'userId': userId,
      'signedAtIso': signedAtIso,
      'verificationUrl': verificationUrl,
    };
  }

  static DocumentSigner? fromJson(Object? input) {
    if (input is! Map) return null;
    final json = input.map((k, v) => MapEntry(k.toString(), v));

    final index = (json['index'] is int) ? json['index'] as int : int.tryParse(json['index']?.toString() ?? '');
    final tenantId = json['tenantId']?.toString().trim();
    final userId = json['userId']?.toString().trim();
    final signedAtIso = json['signedAtIso']?.toString().trim();
    final verificationUrl = json['verificationUrl']?.toString().trim();

    if (index == null || index < 1) return null;
    if (tenantId == null || tenantId.isEmpty) return null;
    if (userId == null || userId.isEmpty) return null;
    if (signedAtIso == null || signedAtIso.isEmpty) return null;
    if (verificationUrl == null || verificationUrl.isEmpty) return null;

    return DocumentSigner(
      index: index,
      tenantId: tenantId,
      userId: userId,
      signedAtIso: signedAtIso,
      verificationUrl: verificationUrl,
    );
  }

  @override
  List<Object?> get props => [index, tenantId, userId, signedAtIso, verificationUrl];
}
