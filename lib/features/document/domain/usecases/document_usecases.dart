import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

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
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) {
    return _repository.pickDocument(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
  }

  Future<List<String>> loadRecentDocuments() {
    return _repository.loadRecentDocuments();
  }

  Future<void> saveRecentDocuments(List<String> documentPaths) {
    return _repository.saveRecentDocuments(documentPaths);
  }

  Future<DocumentIntegrityCheckResult> checkDocumentIntegrity({
    required File pdfFile,
  }) async {
    try {
      final sha256Hex = await _sha256HexOfFile(pdfFile);
      final match = await _findIntegrityMatch(sha256Hex);
      if (match == null) {
        return DocumentIntegrityCheckResult.unknown(sha256Hex: sha256Hex);
      }
      return DocumentIntegrityCheckResult.verified(
        sha256Hex: sha256Hex,
        match: match,
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
    required File originalPdf,
    required String userId,
    required bool consent,
  }) {
    return _repository.requestDocumentSigning(
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

    await for (final entity in appDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final dirName = DocumentWorkspace.basename(entity.path);
      if (!dirName.startsWith('doc_')) continue;

      final integrityFile = File('${entity.path}/integrity.json');
      if (!integrityFile.existsSync()) continue;

      Map<String, dynamic> json;
      try {
        final contents = await integrityFile.readAsString();
        final decoded = jsonDecode(contents);
        if (decoded is! Map<String, dynamic>) continue;
        json = decoded;
      } catch (_) {
        continue;
      }

      final dynamic rawHashes = json['versionHashes'];
      if (rawHashes is! Map) continue;

      for (final entry in rawHashes.entries) {
        final versionKey = entry.key?.toString();
        final storedHash = entry.value?.toString();
        if (versionKey == null || storedHash == null) continue;
        if (storedHash.toLowerCase() != normalizedTarget) continue;

        final versionNumber = int.tryParse(versionKey);
        if (versionNumber == null) continue;

        final docId = dirName.substring('doc_'.length);
        final originalName =
            await DocumentWorkspace.readOriginalName('${entity.path}/original.pdf');

        return DocumentIntegrityMatch(
          docId: docId,
          versionNumber: versionNumber,
          originalName: originalName,
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
  });

  final String docId;
  final int versionNumber;
  final String? originalName;
}

class DocumentIntegrityCheckResult {
  const DocumentIntegrityCheckResult._({
    required this.status,
    required this.sha256Hex,
    this.match,
    this.error,
  });

  factory DocumentIntegrityCheckResult.verified({
    required String sha256Hex,
    required DocumentIntegrityMatch match,
  }) {
    return DocumentIntegrityCheckResult._(
      status: DocumentIntegrityStatus.verified,
      sha256Hex: sha256Hex,
      match: match,
    );
  }

  factory DocumentIntegrityCheckResult.unknown({required String sha256Hex}) {
    return DocumentIntegrityCheckResult._(
      status: DocumentIntegrityStatus.unknown,
      sha256Hex: sha256Hex,
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
  final String? error;
}
