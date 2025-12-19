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

import '../../utils/document_workspace.dart';

class DocumentLocalDataSource {
  static final PdfColor _brandPdfColor = PdfColor(126, 86, 193);

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

  Future<File?> importPdfToAppStorage({required File sourcePdf}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docId = const Uuid().v4();

      final workspaceDir = await Directory('${appDir.path}/doc_$docId').create(
        recursive: true,
      );

      final importedPdf = await sourcePdf.copy('${workspaceDir.path}/original.pdf');

      final meta = <String, dynamic>{
        'schemaVersion': 1,
        'docId': docId,
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
    final regex = RegExp(r'^v(\\d+)\\.pdf$', caseSensitive: false);
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

  Future<Uint8List> mockBackendSignPdf({
    required File originalPdf,
    required String userId,
    required String barcodeData,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final originalBytes = await originalPdf.readAsBytes();
    return stampVerificationBarcodeOnPdf(
      pdfBytes: originalBytes,
      barcodeData: barcodeData,
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
  }) async {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    final qrBytes = await _qrPngBytes(barcodeData);
    final qrBitmap = PdfBitmap(qrBytes);

    final page = document.pages[0];
    final size = page.getClientSize();

    final shortestSide = math.min(size.width, size.height);
    final qrSize = math.max(72.0, math.min(120.0, shortestSide * 0.18));
    const margin = 16.0;

    final x = size.width - margin - qrSize;
    final y = margin;

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
