import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttd/features/document/utils/document_workspace.dart';

void main() {
  group('DocumentWorkspace', () {
    // Normalisasi path supaya assertion stabil di Windows (\\) / Linux (/).
    String _normPath(String path) => path.replaceAll('\\', '/').toLowerCase();

    test('resolveLatestPdfSync returns latest version when available', () async {
      // Setup workspace:
      // - original.pdf
      // - versions/v1.pdf, versions/v10.pdf
      // Harus memilih versi terbesar (v10.pdf).
      final tempDir = await Directory.systemTemp.createTemp('ttd_ws_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workspaceDir = await Directory('${tempDir.path}/doc_123').create();
      await Directory('${workspaceDir.path}/versions').create();

      final original = File('${workspaceDir.path}/original.pdf');
      await original.writeAsBytes(const [0, 1, 2]);

      final v1 = File('${workspaceDir.path}/versions/v1.pdf');
      final v10 = File('${workspaceDir.path}/versions/v10.pdf');
      await v1.writeAsBytes(const [10]);
      await v10.writeAsBytes(const [100]);

      final resolved = DocumentWorkspace.resolveLatestPdfSync(original.path);
      expect(_normPath(resolved.absolute.path), _normPath(v10.absolute.path));
    });

    test('resolveLatestPdfSync falls back to original.pdf when no versions', () async {
      // Kalau tidak ada versi, harus fallback ke original.pdf.
      final tempDir = await Directory.systemTemp.createTemp('ttd_ws_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workspaceDir = await Directory('${tempDir.path}/doc_123').create();
      await Directory('${workspaceDir.path}/versions').create();

      final original = File('${workspaceDir.path}/original.pdf');
      await original.writeAsBytes(const [0, 1, 2]);

      final resolved = DocumentWorkspace.resolveLatestPdfSync(original.path);
      expect(
        _normPath(resolved.absolute.path),
        _normPath(original.absolute.path),
      );
    });

    test('readBackendVerificationUrlSync reads value from meta.json', () async {
      // Meta file `meta.json` menyimpan URL verifikasi backend untuk kasus dokumen signed.
      final tempDir = await Directory.systemTemp.createTemp('ttd_ws_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workspaceDir = await Directory('${tempDir.path}/doc_123').create();
      final original = File('${workspaceDir.path}/original.pdf');
      await original.writeAsBytes(const [0, 1, 2]);

      final meta = File('${workspaceDir.path}/meta.json');
      await meta.writeAsString(
        jsonEncode(<String, dynamic>{
          'backendVerificationUrl': 'http://example.com/verify/abc',
        }),
      );

      final url = DocumentWorkspace.readBackendVerificationUrlSync(original.path);
      expect(url, 'http://example.com/verify/abc');
    });

    test('readOriginalName reads originalName from meta.json', () async {
      // Meta file `meta.json` juga menyimpan nama asli file dari device (originalName).
      final tempDir = await Directory.systemTemp.createTemp('ttd_ws_');
      addTearDown(() => tempDir.delete(recursive: true));

      final workspaceDir = await Directory('${tempDir.path}/doc_123').create();
      final original = File('${workspaceDir.path}/original.pdf');
      await original.writeAsBytes(const [0, 1, 2]);

      final meta = File('${workspaceDir.path}/meta.json');
      await meta.writeAsString(
        jsonEncode(<String, dynamic>{
          'originalName': 'kontrak.pdf',
        }),
      );

      final name = await DocumentWorkspace.readOriginalName(original.path);
      expect(name, 'kontrak.pdf');
    });
  });
}
