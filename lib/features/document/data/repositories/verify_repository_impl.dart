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
      documentId: resp.documentId,
      chainId: resp.chainId,
      versionNumber: resp.versionNumber,
      signedPdfDownloadUrl: resp.signedPdfDownloadUrl,
      signedPdfSha256: resp.signedPdfSha256,
      signers: DocumentSignerMapper.fromJsonList(resp.signers),
    );
  }
}

