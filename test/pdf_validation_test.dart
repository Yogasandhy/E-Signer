import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttd/features/document/utils/pdf_validation.dart';

void main() {
  group('PdfValidation.validatePdfFile', () {
    test('throws when file does not exist', () async {
      // Buat file path yang tidak ada, lalu pastikan validator melempar Exception.
      final tempDir = await Directory.systemTemp.createTemp('ttd_pdf_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/missing.pdf');

      await expectLater(
        PdfValidation.validatePdfFile(file, maxBytes: 10),
        throwsA(
          predicate(
            (e) =>
                e is Exception && e.toString().contains('File tidak ditemukan'),
          ),
        ),
      );
    });

    test('throws when extension is not .pdf', () async {
      // Walaupun kontennya diawali %PDF, tapi ext bukan .pdf → harus ditolak.
      final tempDir = await Directory.systemTemp.createTemp('ttd_pdf_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/not_pdf.txt');
      await file.writeAsBytes(ascii.encode('%PDF-1.7'));

      await expectLater(
        PdfValidation.validatePdfFile(file, maxBytes: 1024),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('File harus berformat PDF'),
          ),
        ),
      );
    });

    test('throws when PDF header is invalid', () async {
      // File .pdf tapi tidak diawali header "%PDF-" → harus ditolak.
      final tempDir = await Directory.systemTemp.createTemp('ttd_pdf_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/bad.pdf');
      await file.writeAsBytes(ascii.encode('HELLO'));

      await expectLater(
        PdfValidation.validatePdfFile(file, maxBytes: 1024),
        throwsA(
          predicate(
            (e) =>
                e is Exception && e.toString().contains('File PDF tidak valid'),
          ),
        ),
      );
    });

    test('passes for a valid small PDF', () async {
      // Minimal PDF: cukup cek header "%PDF-" dan ukuran masih di bawah limit.
      final tempDir = await Directory.systemTemp.createTemp('ttd_pdf_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File('${tempDir.path}/ok.pdf');
      await file.writeAsBytes(ascii.encode('%PDF-1.7\n%...'));

      await PdfValidation.validatePdfFile(file, maxBytes: 1024);
    });

    test('throws when file exceeds maxBytes', () async {
      // File PDF valid tapi ukuran > maxBytes → harus ditolak.
      final tempDir = await Directory.systemTemp.createTemp('ttd_pdf_');
      addTearDown(() => tempDir.delete(recursive: true));

      const maxBytes = 1024 * 1024; // 1MB
      final file = File('${tempDir.path}/big.pdf');

      final bytes = List<int>.filled(maxBytes + 1, 0);
      final header = ascii.encode('%PDF-');
      for (var i = 0; i < header.length; i++) {
        bytes[i] = header[i];
      }
      await file.writeAsBytes(bytes, flush: true);

      await expectLater(
        PdfValidation.validatePdfFile(file, maxBytes: maxBytes),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('Ukuran PDF maksimal'),
          ),
        ),
      );
    });
  });
}
