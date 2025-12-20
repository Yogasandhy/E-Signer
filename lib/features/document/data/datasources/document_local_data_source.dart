import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../utils/document_workspace.dart';

class DocumentLocalDataSource {
  Future<File?> pickDocument({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
    if (result != null) {
      final path = result.files.single.path;
      if (path != null) return File(path);
    }
    return null;
  }

  Future<File?> importPdfToAppStorage({
    required File sourcePdf,
    required String tenantId,
    required String userId,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docId = const Uuid().v4();

      final sanitizedTenantId = _sanitizePathSegment(tenantId);
      final sanitizedUserId = _sanitizePathSegment(userId);

      final workspaceDir = await Directory(
        '${appDir.path}/tenants/$sanitizedTenantId/users/$sanitizedUserId/doc_$docId',
      ).create(
        recursive: true,
      );

      final importedPdf = await sourcePdf.copy('${workspaceDir.path}/original.pdf');

      final meta = <String, dynamic>{
        'schemaVersion': 1,
        'docId': docId,
        'tenantId': tenantId,
        'userId': userId,
        'originalName': DocumentWorkspace.basename(sourcePdf.path),
        'sourcePath': sourcePdf.path,
        'importedAt': DateTime.now().toIso8601String(),
      };
      await File('${workspaceDir.path}/meta.json').writeAsString(jsonEncode(meta));

      await Directory('${workspaceDir.path}/versions').create(recursive: true);

      return importedPdf;
    } catch (_) {
      return null;
    }
  }

  String _sanitizePathSegment(String input) {
    var value = input.trim();
    if (value.isEmpty) return 'unknown';
    value = value.replaceAll(RegExp(r'[<>:"/\\\\|?*]'), '_');
    value = value.replaceAll(RegExp(r'\\s+'), '_');
    return value;
  }

  Future<String?> savePdfToUserSelectedLocation({
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  int _nextWorkspaceVersionNumber(Directory versionsDir) {
    final regex = RegExp(r'^v(\d+)\.pdf$', caseSensitive: false);
    var max = 0;
    if (!versionsDir.existsSync()) return 1;

    for (final entity in versionsDir.listSync()) {
      if (entity is! File) continue;
      final name = DocumentWorkspace.basename(entity.path);
      final match = regex.firstMatch(name);
      if (match == null) continue;
      final n = int.tryParse(match.group(1) ?? '');
      if (n == null) continue;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<SavedWorkspaceVersion?> saveSignedPdfAsNewVersion({
    required File originalPdf,
    required List<int> signedPdfBytes,
    int? versionNumber,
    String? backendDocumentId,
    String? backendChainId,
    String? backendVerificationUrl,
    String? backendSignedPdfSha256,
  }) async {
    final workspaceDir = DocumentWorkspace.findWorkspaceDir(originalPdf.path);
    if (workspaceDir == null) return null;

    final versionsDir =
        await Directory('${workspaceDir.path}/versions').create(recursive: true);

    var resolvedVersionNumber =
        versionNumber ?? _nextWorkspaceVersionNumber(versionsDir);
    var file = File('${versionsDir.path}/v$resolvedVersionNumber.pdf');
    if (file.existsSync()) {
      resolvedVersionNumber = _nextWorkspaceVersionNumber(versionsDir);
      file = File('${versionsDir.path}/v$resolvedVersionNumber.pdf');
    }

    final written = await file
        .writeAsBytes(signedPdfBytes);

    await _recordWorkspaceVersionIntegrity(
      workspaceDir: workspaceDir,
      versionNumber: resolvedVersionNumber,
      pdfBytes: signedPdfBytes,
    );

    final metaFile = File('${workspaceDir.path}/meta.json');
    if (metaFile.existsSync()) {
      try {
        final decoded = jsonDecode(await metaFile.readAsString());
        if (decoded is Map<String, dynamic>) {
          decoded['lastSignedAt'] = DateTime.now().toIso8601String();
          decoded['lastSignedVersion'] = resolvedVersionNumber;
          if ((backendDocumentId ?? '').trim().isNotEmpty) {
            decoded['backendDocumentId'] = backendDocumentId!.trim();
          }
          if ((backendChainId ?? '').trim().isNotEmpty) {
            decoded['backendChainId'] = backendChainId!.trim();
          }
          if ((backendVerificationUrl ?? '').trim().isNotEmpty) {
            decoded['backendVerificationUrl'] = backendVerificationUrl!.trim();
          }
          if ((backendSignedPdfSha256 ?? '').trim().isNotEmpty) {
            decoded['backendSignedPdfSha256'] = backendSignedPdfSha256!.trim();
          }
          await metaFile.writeAsString(jsonEncode(decoded));
        }
      } catch (_) {}
    }

    return SavedWorkspaceVersion(file: written, versionNumber: resolvedVersionNumber);
  }

  Future<void> _recordWorkspaceVersionIntegrity({
    required Directory workspaceDir,
    required int versionNumber,
    required List<int> pdfBytes,
  }) async {
    final file = File('${workspaceDir.path}/integrity.json');
    final sha256Hex = crypto.sha256.convert(pdfBytes).toString();

    Map<String, dynamic> json = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        final contents = await file.readAsString();
        final decoded = jsonDecode(contents);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        json = <String, dynamic>{};
      }
    }

    final metaFile = File('${workspaceDir.path}/meta.json');
    if (metaFile.existsSync()) {
      try {
        final contents = await metaFile.readAsString();
        final decoded = jsonDecode(contents);
        if (decoded is Map<String, dynamic>) {
          final docId = decoded['docId']?.toString();
          final tenantId = decoded['tenantId']?.toString();
          final userId = decoded['userId']?.toString();
          final originalName = decoded['originalName']?.toString();

          if (docId != null && docId.trim().isNotEmpty) {
            json['docId'] = docId;
          }
          if (tenantId != null && tenantId.trim().isNotEmpty) {
            json['tenantId'] = tenantId;
          }
          if (userId != null && userId.trim().isNotEmpty) {
            json['userId'] = userId;
          }
          if (originalName != null && originalName.trim().isNotEmpty) {
            json['originalName'] = originalName;
          }
        }
      } catch (_) {}
    }

    final dynamic rawHashes = json['versionHashes'];
    final Map<String, dynamic> versionHashes = rawHashes is Map
        ? rawHashes.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    versionHashes['$versionNumber'] = sha256Hex;

    json['schemaVersion'] = (json['schemaVersion'] as int?) ?? 1;
    json['algo'] = 'SHA256';
    json['versionHashes'] = versionHashes;
    json['updatedAt'] = DateTime.now().toIso8601String();

    await file.writeAsString(jsonEncode(json));
  }
}

class SavedWorkspaceVersion {
  const SavedWorkspaceVersion({
    required this.file,
    required this.versionNumber,
  });

  final File file;
  final int versionNumber;
}
