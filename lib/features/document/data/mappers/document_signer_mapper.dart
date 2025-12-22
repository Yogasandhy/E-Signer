import '../../domain/entities/document_signer.dart';

class DocumentSignerMapper {
  static DocumentSigner? fromJsonMap(Map<String, dynamic> json) {
    int? index;
    final rawIndex = json['index'];
    if (rawIndex is int) {
      index = rawIndex;
    } else if (rawIndex != null) {
      index = int.tryParse(rawIndex.toString());
    }

    final tenantId = json['tenantId']?.toString();
    final userId = json['userId']?.toString();

    if (index == null || index < 1) return null;
    if (tenantId == null || tenantId.trim().isEmpty) return null;
    if (userId == null || userId.trim().isEmpty) return null;

    return DocumentSigner(
      index: index,
      tenantId: tenantId.trim(),
      userId: userId.trim(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      signedAtIso: json['signedAt']?.toString() ?? '',
    );
  }

  static List<DocumentSigner> fromJsonList(List<Map<String, dynamic>>? json) {
    if (json == null || json.isEmpty) return const <DocumentSigner>[];

    final signers = <DocumentSigner>[];
    for (final entry in json) {
      final signer = fromJsonMap(entry);
      if (signer != null) signers.add(signer);
    }
    return signers;
  }
}

