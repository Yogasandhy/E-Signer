import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:zxing2/qrcode.dart';

import '../../domain/services/tenant_detector.dart';

class PdfQrTenantDetector implements TenantDetector {
  @override
  Future<String?> detectTenantFromPdf({required String pdfPath}) async {
    final pdfFile = File(pdfPath);
    if (!pdfFile.existsSync()) return null;

    return _tryExtractTenantFromPdf(pdfFile);
  }

  Future<String?> _tryExtractTenantFromPdf(File pdfFile) async {
    final qrTenant = await _tryExtractTenantFromPdfQr(pdfFile);
    if (qrTenant != null && qrTenant.trim().isNotEmpty) {
      return qrTenant;
    }

    final pdfrxTenant = await _tryExtractTenantFromPdfTextUsingPdfrx(pdfFile);
    if (pdfrxTenant != null && pdfrxTenant.trim().isNotEmpty) {
      return pdfrxTenant;
    }

    try {
      final length = await pdfFile.length();
      const chunkSize = 1024 * 1024; // 1 MB
      final raf = await pdfFile.open();
      try {
        final headSize = length < chunkSize ? length : chunkSize;
        await raf.setPosition(0);
        final headBytes = await raf.read(headSize);

        List<int> tailBytes = const <int>[];
        if (length > chunkSize) {
          final tailSize =
              length < chunkSize * 2 ? (length - chunkSize) : chunkSize;
          await raf.setPosition(length - tailSize);
          tailBytes = await raf.read(tailSize);
        }

        final combined = <int>[...headBytes, ...tailBytes];
        final text = latin1.decode(combined, allowInvalid: true);
        return _extractTenantFromText(text);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryExtractTenantFromPdfQr(File pdfFile) async {
    try {
      if (kDebugMode) {
        debugPrint('TenantDetector: try QR decode (path=${pdfFile.path})');
      }
      final doc = await PdfDocument.openFile(pdfFile.path);
      try {
        if (doc.pages.isEmpty) return null;

        final candidates = <PdfPage>[
          doc.pages.last,
          if (doc.pages.length > 1) doc.pages[doc.pages.length - 2],
          if (doc.pages.length > 2) doc.pages.first,
        ];

        final decodedUrls = <String>{};

        for (final page in candidates) {
          decodedUrls.addAll(await _decodeQrUrlsFromPdfPage(page));
        }

        if (decodedUrls.isEmpty) return null;

        return _pickBestTenantFromQrUrls(decodedUrls);
      } finally {
        await doc.dispose();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('TenantDetector: QR decode failed: $e');
        debugPrint('$st');
      }
      return null;
    }
  }

  Future<Set<String>> _decodeQrUrlsFromPdfPage(PdfPage page) async {
    final urls = <String>{};

    for (final targetWidth in const <double>[1600, 2400]) {
      final image = await _renderPageImage(page, targetWidth: targetWidth);
      if (image == null) continue;

      try {
        final decoded = _decodeQrStringsFromBgra(
          bgra: image.pixels,
          width: image.width,
          height: image.height,
        );
        urls.addAll(decoded);
      } finally {
        image.dispose();
      }

      if (urls.any((e) => e.toLowerCase().contains('/api/verify/'))) break;
    }

    return urls;
  }

  Future<PdfImage?> _renderPageImage(
    PdfPage page, {
    required double targetWidth,
  }) async {
    try {
      final fullWidth = targetWidth;
      final fullHeight =
          (targetWidth * (page.height / page.width)).roundToDouble();
      return await page.render(
        fullWidth: fullWidth,
        fullHeight: fullHeight,
        backgroundColor: 0xffffffff,
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
      );
    } catch (_) {
      return null;
    }
  }

  Set<String> _decodeQrStringsFromBgra({
    required Uint8List bgra,
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0) return const <String>{};
    if (bgra.length < width * height * 4) return const <String>{};

    final pixels = Int32List(width * height);
    for (var i = 0, p = 0; p < pixels.length; p++, i += 4) {
      final b = bgra[i];
      final g = bgra[i + 1];
      final r = bgra[i + 2];
      pixels[p] = (0xff << 24) | (r << 16) | (g << 8) | b;
    }

    final source = RGBLuminanceSource(width, height, pixels);
    final crops = <LuminanceSource>[source];

    void addCrop({
      required int left,
      required int top,
      required int cropWidth,
      required int cropHeight,
    }) {
      if (cropWidth < 40 || cropHeight < 40) return;
      if (left < 0 || top < 0) return;
      if (left + cropWidth > width || top + cropHeight > height) return;
      try {
        crops.add(source.crop(left, top, cropWidth, cropHeight));
      } catch (_) {
        // ignore invalid crops
      }
    }

    final halfW = (width / 2).floor();
    final halfH = (height / 2).floor();
    final thirdW = (width / 3).floor();
    final thirdH = (height / 3).floor();

    addCrop(
      left: 0,
      top: (height * 2 / 3).floor(),
      cropWidth: width,
      cropHeight: (height / 3).floor(),
    );
    addCrop(
      left: 0,
      top: (height / 2).floor(),
      cropWidth: halfW,
      cropHeight: halfH,
    );
    addCrop(
      left: halfW,
      top: halfH,
      cropWidth: width - halfW,
      cropHeight: height - halfH,
    );

    addCrop(
      left: 0,
      top: (height * 3 / 4).floor(),
      cropWidth: halfW,
      cropHeight: height - (height * 3 / 4).floor(),
    );
    addCrop(
      left: halfW,
      top: (height * 3 / 4).floor(),
      cropWidth: width - halfW,
      cropHeight: height - (height * 3 / 4).floor(),
    );
    addCrop(
      left: 0,
      top: (height * 2 / 3).floor(),
      cropWidth: thirdW,
      cropHeight: height - (height * 2 / 3).floor(),
    );
    addCrop(
      left: thirdW,
      top: (height * 2 / 3).floor(),
      cropWidth: thirdW,
      cropHeight: height - (height * 2 / 3).floor(),
    );
    addCrop(
      left: thirdW * 2,
      top: (height * 2 / 3).floor(),
      cropWidth: width - thirdW * 2,
      cropHeight: height - (height * 2 / 3).floor(),
    );
    addCrop(
      left: 0,
      top: halfH,
      cropWidth: halfW,
      cropHeight: thirdH,
    );
    addCrop(
      left: halfW,
      top: halfH,
      cropWidth: width - halfW,
      cropHeight: thirdH,
    );
    addCrop(
      left: 0,
      top: halfH + thirdH,
      cropWidth: halfW,
      cropHeight: height - (halfH + thirdH),
    );
    addCrop(
      left: halfW,
      top: halfH + thirdH,
      cropWidth: width - halfW,
      cropHeight: height - (halfH + thirdH),
    );

    final decoded = <String>{};
    for (final crop in crops) {
      final text = _tryDecodeQrText(crop);
      if (text != null && text.trim().isNotEmpty) {
        decoded.add(text.trim());
      }
    }

    return decoded;
  }

  String? _tryDecodeQrText(LuminanceSource source) {
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    final reader = QRCodeReader();

    String? decodeWith(Binarizer binarizer) {
      try {
        final result = reader.decode(BinaryBitmap(binarizer), hints: hints);
        return result.text;
      } catch (_) {
        return null;
      }
    }

    return decodeWith(HybridBinarizer(source)) ??
        decodeWith(GlobalHistogramBinarizer(source)) ??
        decodeWith(HybridBinarizer(InvertedLuminanceSource(source))) ??
        decodeWith(GlobalHistogramBinarizer(InvertedLuminanceSource(source)));
  }

  String? _pickBestTenantFromQrUrls(Set<String> urls) {
    final candidates = <({String tenant, int? version})>[];

    final fullUrl = RegExp(
      r'https?://[^\s/]+/([^/\s]+)/api/verify/[^/\s]+/v(\d+)',
      caseSensitive: false,
    );
    final pathOnly = RegExp(
      r'/([^/\s]+)/api/verify/[^/\s]+/v(\d+)',
      caseSensitive: false,
    );

    for (final value in urls) {
      for (final match in fullUrl.allMatches(value)) {
        final tenant = match.group(1)?.trim();
        final version = int.tryParse(match.group(2) ?? '');
        if (tenant == null || tenant.isEmpty) continue;
        candidates.add((tenant: tenant, version: version));
      }
      for (final match in pathOnly.allMatches(value)) {
        final tenant = match.group(1)?.trim();
        final version = int.tryParse(match.group(2) ?? '');
        if (tenant == null || tenant.isEmpty) continue;
        candidates.add((tenant: tenant, version: version));
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final av = a.version ?? -1;
      final bv = b.version ?? -1;
      return bv.compareTo(av);
    });

    return candidates.first.tenant;
  }

  Future<String?> _tryExtractTenantFromPdfTextUsingPdfrx(File pdfFile) async {
    try {
      final doc = await PdfDocument.openFile(pdfFile.path);
      try {
        if (doc.pages.isEmpty) return null;

        final candidates = <PdfPage>[
          doc.pages.last,
          if (doc.pages.length > 1) doc.pages[doc.pages.length - 2],
        ];

        for (final page in candidates) {
          final rawText = await page.loadText();
          final fullText = rawText?.fullText ?? '';
          if (fullText.trim().isEmpty) continue;

          final tenant = _extractBestTenantFromText(fullText);
          if (tenant != null && tenant.trim().isNotEmpty) {
            return tenant.trim();
          }
        }
      } finally {
        await doc.dispose();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? _extractTenantFromText(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'https?://[^\s/]+/([^/\s]+)/api/verify/',
        caseSensitive: false,
      ),
      RegExp(
        r'/([^/\s]+)/api/verify/',
        caseSensitive: false,
      ),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(text);
      final tenant = match?.group(1)?.trim();
      if (tenant != null && tenant.isNotEmpty) {
        return tenant;
      }
    }

    return null;
  }

  String? _extractBestTenantFromText(String text) {
    final candidates = <({String tenant, int? version})>[];

    final fullUrl = RegExp(
      r'https?://[^\s/]+/([^/\s]+)/api/verify/[^/\s]+/v(\d+)',
      caseSensitive: false,
    );
    for (final match in fullUrl.allMatches(text)) {
      final tenant = match.group(1)?.trim();
      final version = int.tryParse(match.group(2) ?? '');
      if (tenant == null || tenant.isEmpty) continue;
      candidates.add((tenant: tenant, version: version));
    }

    final pathOnly = RegExp(
      r'/([^/\s]+)/api/verify/[^/\s]+/v(\d+)',
      caseSensitive: false,
    );
    for (final match in pathOnly.allMatches(text)) {
      final tenant = match.group(1)?.trim();
      final version = int.tryParse(match.group(2) ?? '');
      if (tenant == null || tenant.isEmpty) continue;
      candidates.add((tenant: tenant, version: version));
    }

    if (candidates.isEmpty) {
      return _extractTenantFromText(text);
    }

    candidates.sort((a, b) {
      final av = a.version ?? -1;
      final bv = b.version ?? -1;
      return bv.compareTo(av);
    });

    return candidates.first.tenant;
  }
}
