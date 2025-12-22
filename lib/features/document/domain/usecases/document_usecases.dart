import '../entities/document_signing_result.dart';
import '../entities/document_pick_options.dart';
import '../repositories/document_repository.dart';

class DocumentUseCases {
  DocumentUseCases(this._repository);

  final DocumentRepository _repository;

  factory DocumentUseCases.fromRepository(DocumentRepository repository) {
    return DocumentUseCases(repository);
  }

  Future<String?> pickDocument({
    required String tenantId,
    required String userId,
    DocumentPickOptions options = const DocumentPickOptions(),
  }) {
    return _repository.pickDocument(
      tenantId: tenantId,
      userId: userId,
      options: options,
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
    required String pdfPath,
    required String fileName,
  }) {
    return _repository.savePdfToExternalStorage(
      pdfPath: pdfPath,
      fileName: fileName,
    );
  }

  Future<DocumentSigningResult?> requestDocumentSigning({
    required String tenantId,
    required String accessToken,
    required String originalPdfPath,
    required String userId,
    required bool consent,
    String? idempotencyKey,
  }) {
    return _repository.requestDocumentSigning(
      tenantId: tenantId,
      accessToken: accessToken,
      originalPdfPath: originalPdfPath,
      userId: userId,
      consent: consent,
      idempotencyKey: idempotencyKey,
    );
  }
}
