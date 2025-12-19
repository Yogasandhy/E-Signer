import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../domain/entities/document_signing_result.dart';
import '../../domain/repositories/document_repository.dart';
import '../../utils/document_workspace.dart';
import '../datasources/document_local_data_source.dart';
import '../datasources/recent_file_local_data_source.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentLocalDataSource documentLocalDataSource;
  final RecentFileLocalDataSource recentFileLocalDataSource;

  DocumentRepositoryImpl({
    required this.documentLocalDataSource,
    required this.recentFileLocalDataSource,
  });

  @override
  Future<File?> pickDocument({
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
    );
    if (imported == null) return null;

    return imported;
  }

  @override
  Future<List<String>> loadRecentDocuments() {
    return recentFileLocalDataSource.loadRecentDocuments();
  }

  @override
  Future<void> saveRecentDocuments(List<String> documentPaths) {
    return recentFileLocalDataSource.saveRecentDocuments(documentPaths);
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
    required File originalPdf,
    required String userId,
    required bool consent,
  }) async {
    if (!consent) return null;

    final workspaceDir = DocumentWorkspace.findWorkspaceDir(originalPdf.path);
    final docDirName =
        workspaceDir == null ? '' : DocumentWorkspace.basename(workspaceDir.path);
    final docId = docDirName.startsWith('doc_')
        ? docDirName.substring('doc_'.length)
        : docDirName;

    final existingVersions =
        workspaceDir == null ? const <WorkspaceVersion>[] : DocumentWorkspace.listVersionsSync(workspaceDir);
    final nextVersion =
        existingVersions.isEmpty ? 1 : existingVersions.first.number + 1;
    final verificationUrl =
        (docId.isEmpty) ? null : 'https://example.com/verify/$docId/v$nextVersion';

    final signedBytes = await documentLocalDataSource.mockBackendSignPdf(
      originalPdf: originalPdf,
      userId: userId,
      barcodeData: verificationUrl ?? 'doc:$docId|v:$nextVersion',
    );

    final saved = await documentLocalDataSource.saveSignedPdfAsNewVersion(
      originalPdf: originalPdf,
      signedPdfBytes: signedBytes,
      versionNumber: nextVersion,
    );
    if (saved == null) return null;

    return DocumentSigningResult(
      signedPdf: saved.file,
      versionNumber: saved.versionNumber,
      verificationUrl: verificationUrl,
    );
  }
}
