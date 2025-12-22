import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zxing2/qrcode.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/verify_api.dart';
import '../../utils/document_workspace.dart';
import '../widgets/document_verify_result_dialog.dart';
import '../../../../presentation/app_theme.dart';

class VerifyDocumentScreen extends StatefulWidget {
  const VerifyDocumentScreen({
    super.key,
    required this.tenantController,
  });

  final TextEditingController tenantController;

  @override
  State<VerifyDocumentScreen> createState() => _VerifyDocumentScreenState();
}

class _VerifyDocumentScreenState extends State<VerifyDocumentScreen> {
  bool _isChecking = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hydrateTenant();
  }

  Future<void> _hydrateTenant() async {
    if (widget.tenantController.text.trim().isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existingTenantId = prefs.getString(keyTenantId);
    if (!mounted) return;
    if (existingTenantId != null && existingTenantId.trim().isNotEmpty) {
      widget.tenantController.text = existingTenantId.trim();
    }
  }

  Future<void> _persistTenant(String tenantId) async {
    final t = tenantId.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTenantId, t);
  }

  Future<void> _verifyUploadPdf() async {
    if (_isChecking) return;

    setState(() => _errorText = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final pdfFile = File(path);
    if (!mounted) return;

    setState(() => _isChecking = true);
    try {
      final tenantId = await _resolveTenantIdForVerify(pdfFile: pdfFile);
      if (!mounted) return;
      if (tenantId == null || tenantId.trim().isEmpty) {
        setState(
          () => _errorText =
              'Tenant tidak dapat dideteksi dari QR di PDF. Pastikan PDF memiliki QR verifikasi dari sistem ini (payload berisi /{tenant}/api/verify/{chainId}/v{version}).',
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final verifyApi = context.read<VerifyApi>();
      final check = await verifyApi.verifyPdf(
        tenant: tenantId,
        pdfFile: pdfFile,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;

      await _persistTenant(tenantId);
      if (!mounted) return;
      await showDocumentVerifyResultDialog(
        context: context,
        result: check,
        fileName: DocumentWorkspace.basename(pdfFile.path),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<String?> _resolveTenantIdForVerify({
    required File pdfFile,
  }) async {
    var tenant = widget.tenantController.text.trim();
    if (tenant.isNotEmpty) return tenant;

    tenant = (await _tryExtractTenantFromPdf(pdfFile))?.trim() ?? '';
    if (tenant.isNotEmpty) {
      widget.tenantController.text = tenant;
      await _persistTenant(tenant);
      return tenant;
    }

    return null;
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
          final tailSize = length < chunkSize * 2 ? (length - chunkSize) : chunkSize;
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
        debugPrint('Verify: trying QR decode from PDF (path=${pdfFile.path})');
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

        if (kDebugMode) {
          debugPrint('Verify: QR decoded strings (${decodedUrls.length}):');
          for (final u in decodedUrls.take(6)) {
            debugPrint(' - $u');
          }
          if (decodedUrls.length > 6) debugPrint(' - ...');
        }

        final best = _pickBestTenantFromQrUrls(decodedUrls);
        return best;
      } finally {
        await doc.dispose();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Verify: QR decode failed: $e');
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
        if (kDebugMode) {
          debugPrint(
            'Verify: page=${page.pageNumber} render=${image.width}x${image.height} (targetWidth=$targetWidth) decoded=${decoded.length} total=${urls.length}',
          );
        }
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
      final fullHeight = (targetWidth * (page.height / page.width)).roundToDouble();
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
        // ignore
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

    // Smaller bottom crops to isolate multiple QR codes.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verifikasi Dokumen',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secoundColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isChecking ? null : _verifyUploadPdf,
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_outlined),
            label: const Text('Upload PDF untuk verifikasi'),
          ),
        ),
        if (_errorText != null && _errorText!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(40)),
            ),
            child: Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red[700],
                height: 1.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
