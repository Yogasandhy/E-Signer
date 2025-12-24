import 'dart:io';

import '../../../../core/network/verify_api.dart';
import '../../domain/entities/verify_result.dart';
import '../../domain/repositories/verify_repository.dart';
import '../mappers/document_signer_mapper.dart';

class VerifyRepositoryImpl implements VerifyRepository {
  VerifyRepositoryImpl({required VerifyApi api}) : _api = api;

  final VerifyApi _api;

  @override
  Future<VerifyResult> verifyPdf({
    required String tenant,
    required String pdfPath,
  }) async {
    final resp = await _api.verifyPdf(
      tenant: tenant,
      pdfFile: File(pdfPath),
    );

    return VerifyResult(
      valid: resp.valid,
      reason: resp.reason,
      documentId: resp.documentId,
      chainId: resp.chainId,
      versionNumber: resp.versionNumber,
      signedPdfDownloadUrl: resp.signedPdfDownloadUrl,
      signedPdfSha256: resp.signedPdfSha256,
      expectedSignedPdfSha256: resp.expectedSignedPdfSha256,
      signatureValid: resp.signatureValid,
      certificateStatus: resp.certificateStatus,
      rootCaFingerprint: resp.rootCaFingerprint,
      certificateRevokedAt: resp.certificateRevokedAt,
      certificateRevokedReason: resp.certificateRevokedReason,
      tsaStatus: resp.tsaStatus,
      tsaSignedAt: resp.tsaSignedAt,
      tsaFingerprint: resp.tsaFingerprint,
      tsaReason: resp.tsaReason,
      ltvStatus: resp.ltvStatus,
      ltvGeneratedAt: resp.ltvGeneratedAt,
      ltvIssues: resp.ltvIssues ?? const <String>[],
      signers: DocumentSignerMapper.fromJsonList(resp.signers),
    );
  }
}
