import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../entities/document_signing_chain.dart';
import '../entities/document_signing_result.dart';
import '../repositories/document_repository.dart';
import '../../utils/document_workspace.dart';

class DocumentUseCases {
  DocumentUseCases(this._repository);

  final DocumentRepository _repository;

  factory DocumentUseCases.fromRepository(DocumentRepository repository) {
    return DocumentUseCases(repository);
  }

  Future<File?> pickDocument({
    required String tenantId,
    required String userId,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) {
    return _repository.pickDocument(
      tenantId: tenantId,
      userId: userId,
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
  }

  Future<List<String>> loadRecentDocuments({
    required String tenantId,
    required String userId,
  }) {
    return _repository.loadRecentDocuments(
      tenantId: tenantId,
      userId: userId,
    );
  }

  Future<void> saveRecentDocuments({
    required String tenantId,
    required String userId,
    required List<String> documentPaths,
  }) {
    return _repository.saveRecentDocuments(
      tenantId: tenantId,
      userId: userId,
      documentPaths: documentPaths,
    );
  }

  Future<DocumentIntegrityCheckResult> checkDocumentIntegrity({
    required File pdfFile,
  }) async {
    try {
      DocumentSigningChain? signingChain;
      try {
        signingChain = await _repository.readSigningChainFromPdf(pdfFile: pdfFile);
      } catch (_) {
        signingChain = null;
      }
      final sha256Hex = await _sha256HexOfFile(pdfFile);
      final match = await _findIntegrityMatch(sha256Hex);
      if (match == null) {
        return DocumentIntegrityCheckResult.unknown(
          sha256Hex: sha256Hex,
          signingChain: signingChain,
        );
      }
      return DocumentIntegrityCheckResult.verified(
        sha256Hex: sha256Hex,
        match: match,
        signingChain: signingChain,
      );
    } catch (e) {
      return DocumentIntegrityCheckResult.error(error: e.toString());
    }
  }

  Future<String?> savePdfToExternalStorage({
    required File pdfFile,
    required String fileName,
  }) {
    return _repository.savePdfToExternalStorage(
      pdfFile: pdfFile,
      fileName: fileName,
    );
  }

  Future<DocumentSigningResult?> requestDocumentSigning({
    required String tenantId,
    required File originalPdf,
    required String userId,
    required bool consent,
  }) {
    return _repository.requestDocumentSigning(
      tenantId: tenantId,
      originalPdf: originalPdf,
      userId: userId,
      consent: consent,
    );
  }

  Future<String> _sha256HexOfFile(File file) async {
    final digest = await crypto.sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<DocumentIntegrityMatch?> _findIntegrityMatch(String sha256Hex) async {
    final appDir = await getApplicationDocumentsDirectory();
    final normalizedTarget = sha256Hex.toLowerCase();

    await for (final entity in appDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (DocumentWorkspace.basename(entity.path) != 'integrity.json') continue;

      final workspaceDir = entity.parent;
      final dirName = DocumentWorkspace.basename(workspaceDir.path);
      if (!dirName.startsWith('doc_')) continue;

      Map<String, dynamic> integrityJson;
      try {
        final contents = await entity.readAsString();
        final decoded = jsonDecode(contents);
        if (decoded is! Map<String, dynamic>) continue;
        integrityJson = decoded;
      } catch (_) {
        continue;
      }

      final dynamic rawHashes = integrityJson['versionHashes'];
      if (rawHashes is! Map) continue;

      for (final entry in rawHashes.entries) {
        final versionKey = entry.key?.toString();
        final storedHash = entry.value?.toString();
        if (versionKey == null || storedHash == null) continue;
        if (storedHash.toLowerCase() != normalizedTarget) continue;

        final versionNumber = int.tryParse(versionKey);
        if (versionNumber == null) continue;

        final docId = dirName.substring('doc_'.length);
        final originalName = await DocumentWorkspace.readOriginalName(
          '${workspaceDir.path}/original.pdf',
        );

        String? tenantId;
        String? userId;
        final metaFile = File('${workspaceDir.path}/meta.json');
        if (metaFile.existsSync()) {
          try {
            final metaDecoded = jsonDecode(await metaFile.readAsString());
            if (metaDecoded is Map<String, dynamic>) {
              tenantId = metaDecoded['tenantId']?.toString();
              userId = metaDecoded['userId']?.toString();
            }
          } catch (_) {}
        }

        return DocumentIntegrityMatch(
          docId: docId,
          versionNumber: versionNumber,
          originalName: originalName,
          tenantId: tenantId,
          userId: userId,
        );
      }
    }

    return null;
  }
}

enum DocumentIntegrityStatus {
  verified,
  unknown,
  error,
}

class DocumentIntegrityMatch {
  const DocumentIntegrityMatch({
    required this.docId,
    required this.versionNumber,
    this.originalName,
    this.tenantId,
    this.userId,
  });

  final String docId;
  final int versionNumber;
  final String? originalName;
  final String? tenantId;
  final String? userId;
}

class DocumentIntegrityCheckResult {
  const DocumentIntegrityCheckResult._({
    required this.status,
    required this.sha256Hex,
    this.match,
    this.signingChain,
    this.error,
  });

  factory DocumentIntegrityCheckResult.verified({
    required String sha256Hex,
    required DocumentIntegrityMatch match,
    DocumentSigningChain? signingChain,
  }) {
    return DocumentIntegrityCheckResult._(
      status: DocumentIntegrityStatus.verified,
      sha256Hex: sha256Hex,
      match: match,
      signingChain: signingChain,
    );
  }

  factory DocumentIntegrityCheckResult.unknown({
    required String sha256Hex,
    DocumentSigningChain? signingChain,
  }) {
    return DocumentIntegrityCheckResult._(
      status: DocumentIntegrityStatus.unknown,
      sha256Hex: sha256Hex,
      signingChain: signingChain,
    );
  }

  factory DocumentIntegrityCheckResult.error({required String error}) {
    return DocumentIntegrityCheckResult._(
      status: DocumentIntegrityStatus.error,
      sha256Hex: '',
      error: error,
    );
  }

  final DocumentIntegrityStatus status;
  final String sha256Hex;
  final DocumentIntegrityMatch? match;
  final DocumentSigningChain? signingChain;
  final String? error;
}
