import 'package:equatable/equatable.dart';

import 'document_signer.dart';

class VerifyResult extends Equatable {
  const VerifyResult({
    required this.valid,
    this.reason,
    this.documentId,
    this.chainId,
    this.versionNumber,
    this.signedPdfDownloadUrl,
    this.signedPdfSha256,
    this.expectedSignedPdfSha256,
    this.signatureValid,
    this.certificateStatus,
    this.rootCaFingerprint,
    this.certificateRevokedAt,
    this.certificateRevokedReason,
    this.tsaStatus,
    this.tsaSignedAt,
    this.tsaFingerprint,
    this.tsaReason,
    this.ltvStatus,
    this.ltvGeneratedAt,
    this.ltvIssues = const <String>[],
    this.signers = const <DocumentSigner>[],
  });

  final bool valid;
  final String? reason;
  final String? documentId;
  final String? chainId;
  final int? versionNumber;
  final String? signedPdfDownloadUrl;
  final String? signedPdfSha256;
  final String? expectedSignedPdfSha256;

  /// Digital signature validation result on server, can be null for legacy docs.
  final bool? signatureValid;

  /// Certificate status on server side (Root CA + CRL check).
  /// Known values: valid, expired, revoked, untrusted, not_yet_valid, missing.
  final String? certificateStatus;

  final String? rootCaFingerprint;
  final String? certificateRevokedAt;
  final String? certificateRevokedReason;

  /// TSA validation status from server (RFC 3161).
  /// Known values: valid, invalid, missing.
  final String? tsaStatus;
  final String? tsaSignedAt;
  final String? tsaFingerprint;
  final String? tsaReason;

  /// LTV status from server.
  /// Known values: ready, incomplete, missing.
  final String? ltvStatus;
  final String? ltvGeneratedAt;
  final List<String> ltvIssues;
  final List<DocumentSigner> signers;

  @override
  List<Object?> get props => [
        valid,
        reason,
        documentId,
        chainId,
        versionNumber,
        signedPdfDownloadUrl,
        signedPdfSha256,
        expectedSignedPdfSha256,
        signatureValid,
        certificateStatus,
        rootCaFingerprint,
        certificateRevokedAt,
        certificateRevokedReason,
        tsaStatus,
        tsaSignedAt,
        tsaFingerprint,
        tsaReason,
        ltvStatus,
        ltvGeneratedAt,
        ltvIssues,
        signers,
      ];
}
