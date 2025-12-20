import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../entities/document_signing_result.dart';
import '../repositories/document_repository.dart';

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
    required String accessToken,
    required File originalPdf,
    required String userId,
    required bool consent,
  }) {
    return _repository.requestDocumentSigning(
      tenantId: tenantId,
      accessToken: accessToken,
      originalPdf: originalPdf,
      userId: userId,
      consent: consent,
    );
  }
}
