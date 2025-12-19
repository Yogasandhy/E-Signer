import 'package:equatable/equatable.dart';

class DocumentSigningChain extends Equatable {
  const DocumentSigningChain({
    required this.schemaVersion,
    required this.chainId,
    required this.signers,
  });

  final int schemaVersion;
  final String chainId;
  final List<DocumentSigner> signers;

  DocumentSigningChain copyWith({
    int? schemaVersion,
    String? chainId,
    List<DocumentSigner>? signers,
  }) {
    return DocumentSigningChain(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      chainId: chainId ?? this.chainId,
      signers: signers ?? this.signers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'chainId': chainId,
      'signers': signers.map((s) => s.toJson()).toList(),
    };
  }

  static DocumentSigningChain? fromJson(Object? input) {
    if (input is! Map) return null;
    final json = input.map((k, v) => MapEntry(k.toString(), v));

    final schemaVersion = (json['schemaVersion'] is int) ? json['schemaVersion'] as int : 1;
    final chainId = json['chainId']?.toString().trim();
    if (chainId == null || chainId.isEmpty) return null;

    final rawSigners = json['signers'];
    final signers = <DocumentSigner>[];
    if (rawSigners is List) {
      for (final entry in rawSigners) {
        final signer = DocumentSigner.fromJson(entry);
        if (signer != null) signers.add(signer);
      }
    }

    return DocumentSigningChain(
      schemaVersion: schemaVersion,
      chainId: chainId,
      signers: signers,
    );
  }

  @override
  List<Object?> get props => [schemaVersion, chainId, signers];
}

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

