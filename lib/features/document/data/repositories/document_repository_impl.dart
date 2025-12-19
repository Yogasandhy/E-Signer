import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/document_signing_chain.dart';
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
    required File originalPdf,
    required String userId,
    required bool consent,
  }) async {
    if (!consent) return null;

    final workspaceDir = DocumentWorkspace.findWorkspaceDir(originalPdf.path);
    final existingVersions =
        workspaceDir == null ? const <WorkspaceVersion>[] : DocumentWorkspace.listVersionsSync(workspaceDir);
    final nextVersion =
        existingVersions.isEmpty ? 1 : existingVersions.first.number + 1;

    final basePdf = existingVersions.isEmpty ? originalPdf : existingVersions.first.file;

    final existingChain =
        await documentLocalDataSource.readSigningChainFromPdf(pdfFile: basePdf);
    final chain = existingChain ?? DocumentSigningChain(
      schemaVersion: 1,
      chainId: '',
      signers: const <DocumentSigner>[],
    );

    final chainId = chain.chainId.trim().isEmpty ? const Uuid().v4() : chain.chainId;
    final signerIndex = chain.signers.length + 1;
    final verificationUrl =
        'https://example.com/verify/$tenantId/$chainId/sig/$signerIndex/v$nextVersion';

    final signer = DocumentSigner(
      index: signerIndex,
      tenantId: tenantId,
      userId: userId,
      signedAtIso: DateTime.now().toIso8601String(),
      verificationUrl: verificationUrl,
    );
    final updatedChain = DocumentSigningChain(
      schemaVersion: chain.schemaVersion,
      chainId: chainId,
      signers: [...chain.signers, signer],
    );

    final signedBytes = await documentLocalDataSource.mockBackendSignPdf(
      inputPdf: basePdf,
      signingChain: updatedChain,
      barcodeData: verificationUrl,
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

  @override
  Future<DocumentSigningChain?> readSigningChainFromPdf({required File pdfFile}) {
    return documentLocalDataSource.readSigningChainFromPdf(pdfFile: pdfFile);
  }
}
