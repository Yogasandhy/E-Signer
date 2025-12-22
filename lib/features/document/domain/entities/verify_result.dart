import 'package:equatable/equatable.dart';

import 'document_signer.dart';

class VerifyResult extends Equatable {
  const VerifyResult({
    required this.valid,
    this.documentId,
    this.chainId,
    this.versionNumber,
    this.signedPdfDownloadUrl,
    this.signedPdfSha256,
    this.signers = const <DocumentSigner>[],
  });

  final bool valid;
  final String? documentId;
  final String? chainId;
  final int? versionNumber;
  final String? signedPdfDownloadUrl;
  final String? signedPdfSha256;
  final List<DocumentSigner> signers;

  @override
  List<Object?> get props => [
        valid,
        documentId,
        chainId,
        versionNumber,
        signedPdfDownloadUrl,
        signedPdfSha256,
        signers,
      ];
}

