import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/document_pick_options.dart';
import '../../domain/entities/document_signing_result.dart';
import '../../domain/repositories/document_repository.dart';
import '../../utils/document_workspace.dart';
import '../datasources/document_local_data_source.dart';
import '../datasources/recent_file_local_data_source.dart';
import '../../../../core/network/document_api.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentLocalDataSource documentLocalDataSource;
  final RecentFileLocalDataSource recentFileLocalDataSource;
  final DocumentApi documentApi;

  DocumentRepositoryImpl({
    required this.documentLocalDataSource,
    required this.recentFileLocalDataSource,
    required this.documentApi,
  });

  @override
  Future<String?> pickDocument({
    required String tenantId,
    required String userId,
    DocumentPickOptions options = const DocumentPickOptions(),
  }) async {
    final picked = await documentLocalDataSource.pickDocument(
      type: FileType.custom,
      allowedExtensions: options.allowedExtensions ?? const ['pdf'],
      allowMultiple: options.allowMultiple,
    );
    if (picked == null) return null;

    final imported = await documentLocalDataSource.importPdfToAppStorage(
      sourcePdf: picked,
      tenantId: tenantId,
      userId: userId,
    );
    if (imported == null) return null;

    return imported.path;
  }

  @override
  Future<List<String>> loadRecentDocuments({
    required String tenantId,
    required String userId,
  }) {
    return recentFileLocalDataSource.loadRecentDocuments(
      tenantId: tenantId,
      userId: userId,
    );
  }

  @override
  Future<void> saveRecentDocuments({
    required String tenantId,
    required String userId,
    required List<String> documentPaths,
  }) {
    return recentFileLocalDataSource.saveRecentDocuments(
      tenantId: tenantId,
      userId: userId,
      documentPaths: documentPaths,
    );
  }

  @override
  Future<String?> savePdfToExternalStorage({
    required String pdfPath,
    required String fileName,
  }) async {
    try {
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) return null;
      return await documentLocalDataSource.savePdfToUserSelectedLocation(
        fileName: fileName,
        bytes: await pdfFile.readAsBytes(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DocumentSigningResult?> requestDocumentSigning({
    required String tenantId,
    required String accessToken,
    required String originalPdfPath,
    required String userId,
    required bool consent,
    String? idempotencyKey,
  }) async {
    if (!consent) return null;

    final originalPdf = File(originalPdfPath);
    if (!originalPdf.existsSync()) return null;

    final workspaceDir = DocumentWorkspace.findWorkspaceDir(originalPdf.path);
    final existingVersions =
        workspaceDir == null ? const <WorkspaceVersion>[] : DocumentWorkspace.listVersionsSync(workspaceDir);
    final basePdf = existingVersions.isEmpty ? originalPdf : existingVersions.first.file;

    final sign = await documentApi.signDocument(
      tenant: tenantId,
      accessToken: accessToken,
      pdfFile: basePdf,
      consent: consent,
      idempotencyKey: idempotencyKey,
    );

    final signedBytes = await documentApi.downloadPdfBytes(
      url: sign.signedPdfDownloadUrl,
      accessToken: accessToken,
    );

    final saved = await documentLocalDataSource.saveSignedPdfAsNewVersion(
      originalPdf: originalPdf,
      signedPdfBytes: signedBytes,
      versionNumber: sign.versionNumber,
      backendDocumentId: sign.documentId,
      backendChainId: sign.chainId,
      backendVerificationUrl: sign.verificationUrl,
      backendSignedPdfSha256: sign.signedPdfSha256,
    );
    if (saved == null) return null;

    return DocumentSigningResult(
      signedPdfPath: saved.file.path,
      versionNumber: saved.versionNumber,
      verificationUrl: sign.verificationUrl,
    );
  }
}
