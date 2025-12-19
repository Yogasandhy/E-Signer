import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/document_signing_chain.dart';
import '../../utils/document_workspace.dart';

class DocumentLocalDataSource {
  static final PdfColor _brandPdfColor = PdfColor(126, 86, 193);
  static const String _signingMetaTag = 'TTD_META:';

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

  Future<DocumentSigningChain?> readSigningChainFromPdf({
    required File pdfFile,
  }) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final chain = _readSigningChainFromDocument(document);
      document.dispose();
      return chain;
    } catch (_) {
      return null;
    }
  }

  DocumentSigningChain? _readSigningChainFromDocument(PdfDocument document) {
    final keywords = document.documentInformation.keywords;
    if (keywords.trim().isEmpty) return null;

    final match = RegExp(r'TTD_META:([A-Za-z0-9_=-]+)').firstMatch(keywords);
    if (match == null) return null;

    final raw = match.group(1);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final padded = _padBase64(raw.trim());
      final decoded = utf8.decode(base64Url.decode(padded));
      final json = jsonDecode(decoded);
      return DocumentSigningChain.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void _writeSigningChainToDocument({
    required PdfDocument document,
    required DocumentSigningChain signingChain,
  }) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(signingChain.toJson())));
    final token = '$_signingMetaTag$encoded';
    document.documentInformation.keywords = token;
  }

  String _padBase64(String input) {
    final mod = input.length % 4;
    if (mod == 0) return input;
    if (mod == 2) return '$input==';
    if (mod == 3) return '$input=';
    return input;
  }

  Future<Uint8List> mockBackendSignPdf({
    required File inputPdf,
    required DocumentSigningChain signingChain,
    required String barcodeData,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final originalBytes = await inputPdf.readAsBytes();
    return stampVerificationBarcodeOnPdf(
      pdfBytes: originalBytes,
      barcodeData: barcodeData,
      signingChain: signingChain,
    );
  }

  Future<SavedWorkspaceVersion?> saveSignedPdfAsNewVersion({
    required File originalPdf,
    required List<int> signedPdfBytes,
    int? versionNumber,
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
          await metaFile.writeAsString(jsonEncode(decoded));
        }
      } catch (_) {}
    }

    return SavedWorkspaceVersion(file: written, versionNumber: resolvedVersionNumber);
  }

  Future<Uint8List> stampVerificationBarcodeOnPdf({
    required Uint8List pdfBytes,
    required String barcodeData,
    required DocumentSigningChain signingChain,
  }) async {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    final qrIndex = signingChain.signers.length - 1;
    if (qrIndex < 0) {
      document.dispose();
      throw StateError('signingChain.signers is empty.');
    }
    _writeSigningChainToDocument(document: document, signingChain: signingChain);

    final qrBytes = await _qrPngBytes(barcodeData);
    final qrBitmap = PdfBitmap(qrBytes);

    final page = document.pages[0];
    final size = page.getClientSize();

    final shortestSide = math.min(size.width, size.height);
    final qrSize = math.max(72.0, math.min(120.0, shortestSide * 0.18));
    const margin = 16.0;
    const spacing = 12.0;

    final availableHeight = math.max(0.0, size.height - (margin * 2));
    var maxRows = ((availableHeight + spacing) / (qrSize + spacing)).floor();
    if (maxRows < 1) maxRows = 1;

    final row = (qrIndex <= 0) ? 0 : (qrIndex % maxRows);
    final col = (qrIndex <= 0) ? 0 : (qrIndex ~/ maxRows);

    var x = size.width - margin - qrSize - (col * (qrSize + spacing));
    var y = margin + (row * (qrSize + spacing));

    if (x < margin) x = margin;
    if (y < margin) y = margin;

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: ui.Rect.fromLTWH(x - 2, y - 2, qrSize + 4, qrSize + 4),
    );
    page.graphics.drawImage(
      qrBitmap,
      ui.Rect.fromLTWH(x, y, qrSize, qrSize),
    );
    page.graphics.drawRectangle(
      pen: PdfPen(_brandPdfColor, width: 1),
      bounds: ui.Rect.fromLTWH(x - 2, y - 2, qrSize + 4, qrSize + 4),
    );

    final out = Uint8List.fromList(await document.save());
    document.dispose();
    return out;
  }

  Future<Uint8List> _qrPngBytes(String data) async {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    const quietZoneModules = 4;

    // Try to keep the QR crisp by using an integer pixel size per module.
    const targetPixels = 256;
    var pixelsPerModule =
        (targetPixels / (qrImage.moduleCount + (quietZoneModules * 2))).floor();
    if (pixelsPerModule < 1) pixelsPerModule = 1;

    final imageSize =
        (qrImage.moduleCount + (quietZoneModules * 2)) * pixelsPerModule;
    final size = imageSize.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint()..isAntiAlias = false;
    paint.color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size, size), paint);

    paint.color = const ui.Color(0xFF000000);
    for (var row = 0; row < qrImage.moduleCount; row++) {
      for (var col = 0; col < qrImage.moduleCount; col++) {
        if (!qrImage.isDark(row, col)) continue;

        final left = (col + quietZoneModules) * pixelsPerModule.toDouble();
        final top = (row + quietZoneModules) * pixelsPerModule.toDouble();
        canvas.drawRect(
          ui.Rect.fromLTWH(
            left,
            top,
            pixelsPerModule.toDouble(),
            pixelsPerModule.toDouble(),
          ),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(imageSize, imageSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode QR PNG bytes.');
    }
    return byteData.buffer.asUint8List();
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
