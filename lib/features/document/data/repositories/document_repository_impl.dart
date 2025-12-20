import 'dart:io';

import 'package:file_picker/file_picker.dart';

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
  Future<File?> pickDocument({
    required String tenantId,
    required String userId,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    final picked = await documentLocalDataSource.pickDocument(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
    if (picked == null) return null;

    final imported = await documentLocalDataSource.importPdfToAppStorage(
      sourcePdf: picked,
      tenantId: tenantId,
      userId: userId,
    );
    if (imported == null) return null;

    return imported;
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
    required File pdfFile,
    required String fileName,
  }) async {
    try {
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
    required File originalPdf,
    required String userId,
    required bool consent,
  }) async {
    if (!consent) return null;

    final workspaceDir = DocumentWorkspace.findWorkspaceDir(originalPdf.path);
    final existingVersions =
        workspaceDir == null ? const <WorkspaceVersion>[] : DocumentWorkspace.listVersionsSync(workspaceDir);
    final basePdf = existingVersions.isEmpty ? originalPdf : existingVersions.first.file;

    final sign = await documentApi.signDocument(
      tenant: tenantId,
      accessToken: accessToken,
      pdfFile: basePdf,
      consent: consent,
    );

    final signedBytes =
        await documentApi.downloadPdfBytes(url: sign.signedPdfDownloadUrl);

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
      signedPdf: saved.file,
      versionNumber: saved.versionNumber,
      verificationUrl: sign.verificationUrl,
    );
  }
}
