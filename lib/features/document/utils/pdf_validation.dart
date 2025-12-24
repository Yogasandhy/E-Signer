import 'dart:convert';
import 'dart:io';

class PdfValidation {
  static Future<void> validatePdfFile(
    File pdfFile, {
    required int maxBytes,
  }) async {
    if (!pdfFile.existsSync()) {
      throw Exception('File tidak ditemukan.');
    }

    final fileName = pdfFile.uri.pathSegments.isNotEmpty
        ? pdfFile.uri.pathSegments.last
        : pdfFile.path.split(RegExp(r'[/\\\\]')).last;
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      throw Exception('File harus berformat PDF.');
    }

    if (!await _hasPdfHeader(pdfFile)) {
      throw Exception('File PDF tidak valid.');
    }

    final size = await pdfFile.length();
    if (maxBytes > 0 && size > maxBytes) {
      final maxMb = maxBytes / (1024 * 1024);
      final maxText = (maxMb % 1 == 0)
          ? maxMb.toInt().toString()
          : maxMb.toStringAsFixed(1);
      throw Exception('Ukuran PDF maksimal $maxText MB.');
    }
  }

  static Future<bool> _hasPdfHeader(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final bytes = await raf.read(5);
      if (bytes.length < 5) return false;
      final header = ascii.decode(bytes, allowInvalid: true);
      return header == '%PDF-';
    } catch (_) {
      return false;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }
}

