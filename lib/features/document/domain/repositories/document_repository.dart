import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../entities/document_signing_result.dart';

abstract class DocumentRepository {
  Future<File?> pickDocument({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  });

  Future<List<String>> loadRecentDocuments();

  Future<void> saveRecentDocuments(List<String> documentPaths);

  Future<String?> savePdfToExternalStorage({
    required File pdfFile,
    required String fileName,
  });

  Future<DocumentSigningResult?> requestDocumentSigning({
    required File originalPdf,
    required String userId,
    required bool consent,
  });
}
