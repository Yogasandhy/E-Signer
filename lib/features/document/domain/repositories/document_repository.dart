import '../entities/document_signing_result.dart';
import '../entities/document_pick_options.dart';

abstract class DocumentRepository {
  Future<String?> pickDocument({
    required String tenantId,
    required String userId,
    DocumentPickOptions options = const DocumentPickOptions(),
  });

  Future<List<String>> loadRecentDocuments({
    required String tenantId,
    required String userId,
  });

  Future<void> saveRecentDocuments({
    required String tenantId,
    required String userId,
    required List<String> documentPaths,
  });

  Future<String?> savePdfToExternalStorage({
    required String pdfPath,
    required String fileName,
  });

  Future<DocumentSigningResult?> requestDocumentSigning({
    required String tenantId,
    required String accessToken,
    required String originalPdfPath,
    required String userId,
    required bool consent,
    String? idempotencyKey,
  });
}
