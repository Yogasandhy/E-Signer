import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../../domain/usecases/document_usecases.dart';
import '../../utils/pdf_file_name.dart';
import '../../utils/document_workspace.dart';
import '../widgets/version_history_sheet.dart';
import '../../../../presentation/app_theme.dart';

enum PdfViewerMode {
  preview,
  signedResult,
}

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.pdfFile,
    required this.mode,
    this.verificationUrl,
    this.tenantId,
    this.userId,
    this.accessToken,
  });

  final File pdfFile;
  final PdfViewerMode mode;
  final String? verificationUrl;
  final String? tenantId;
  final String? userId;
  final String? accessToken;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _pdfViewerCtrl;
  bool _consentChecked = false;
  bool _isSigning = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _pdfViewerCtrl = PdfViewerController();
    _idempotencyKey = const Uuid().v4();
  }

  Future<void> _onSignPressed({
    required BuildContext context,
    required DocumentUseCases documentUseCases,
  }) async {
    if (_isSigning || !_consentChecked) return;
    final userId = widget.userId?.trim();
    final tenantId = widget.tenantId?.trim();
    final accessToken = widget.accessToken?.trim();
    if (tenantId == null ||
        tenantId.isEmpty ||
        userId == null ||
        userId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum login.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSigning = true);
    try {
      final signed = await documentUseCases.requestDocumentSigning(
        originalPdfPath: widget.pdfFile.path,
        tenantId: tenantId,
        accessToken: accessToken,
        userId: userId,
        consent: true,
        idempotencyKey: _idempotencyKey,
      );

      if (!context.mounted) return;
      setState(() => _isSigning = false);

      if (signed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal signing. Coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            pdfFile: File(signed.signedPdfPath),
            mode: PdfViewerMode.signedResult,
            verificationUrl: signed.verificationUrl,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isSigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAsPdfFile({
    required BuildContext context,
    required DocumentUseCases documentUseCases,
    required File sourcePdf,
  }) async {
    final suggested = await _suggestedSaveFileName(sourcePdf);

    final sanitized = PdfFileName.sanitizePdfFileName(suggested);
    final saved = await documentUseCases.savePdfToExternalStorage(
      pdfPath: sourcePdf.path,
      fileName: sanitized,
    );

    if (!context.mounted) return;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save canceled.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: $saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<String> _suggestedSaveFileName(File sourcePdf) async {
    final fallback = (DocumentWorkspace.basename(sourcePdf.path).trim().isEmpty)
        ? 'document.pdf'
        : DocumentWorkspace.basename(sourcePdf.path);

    final workspaceDir = DocumentWorkspace.findWorkspaceDir(sourcePdf.path);
    if (workspaceDir == null) return fallback;

    final originalName =
        await DocumentWorkspace.readOriginalName('${workspaceDir.path}/original.pdf');
    if (originalName == null || originalName.trim().isEmpty) return fallback;

    final versionNumber =
        PdfFileName.tryParseVersionNumber(DocumentWorkspace.basename(sourcePdf.path));
    if (versionNumber == null) return PdfFileName.sanitizePdfFileName(originalName);

    final base = PdfFileName.withoutPdfExtension(originalName.trim());
    return '${base}__signed_v$versionNumber.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final documentUseCases = context.read<DocumentUseCases>();
    final title = switch (widget.mode) {
      PdfViewerMode.preview => 'Preview Dokumen',
      PdfViewerMode.signedResult => 'Hasil Tanda Tangan',
    };

    final viewerParams = PdfViewerParams(
      scaleEnabled: true,
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        final progress =
            (totalBytes != null && totalBytes > 0) ? bytesDownloaded / totalBytes : null;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  color: AppTheme.secoundColor,
                ),
                const SizedBox(height: 12),
                const Text('Memuat dokumen...'),
              ],
            ),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.mode == PdfViewerMode.signedResult) ...[
            IconButton(
              tooltip: 'Save As',
              icon: Icon(MdiIcons.download),
              onPressed: () async {
                await _saveAsPdfFile(
                  context: context,
                  documentUseCases: documentUseCases,
                  sourcePdf: widget.pdfFile,
                );
              },
            ),
            IconButton(
              tooltip: 'History',
              icon: Icon(MdiIcons.history),
              onPressed: () async {
                final workspaceDir =
                    DocumentWorkspace.findWorkspaceDir(widget.pdfFile.path);
                if (workspaceDir == null) return;

                await showVersionHistorySheet(
                  context: context,
                  workspaceDir: workspaceDir,
                );
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.verificationUrl != null &&
                widget.verificationUrl!.trim().isNotEmpty &&
                widget.mode == PdfViewerMode.signedResult) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secoundColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secoundColor.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.qrcodeScan, color: AppTheme.secoundColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Verification URL tersedia',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: PdfViewer.file(
                widget.pdfFile.path,
                controller: _pdfViewerCtrl,
                params: viewerParams,
              ),
            ),
            if (widget.mode == PdfViewerMode.preview) ...[
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _consentChecked,
                            onChanged: _isSigning
                                ? null
                                : (value) => setState(
                                      () => _consentChecked = value ?? false,
                                    ),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 12.0),
                              child: Text(
                                'Saya setuju dan ingin menandatangani dokumen ini.',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secoundColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppTheme.secoundColor.withAlpha(140),
                            disabledForegroundColor: Colors.white,
                          ),
                          onPressed: (_consentChecked && !_isSigning)
                              ? () => _onSignPressed(
                                    context: context,
                                    documentUseCases: documentUseCases,
                                  )
                              : null,
                          child: _isSigning
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.draw_rounded),
                                    SizedBox(width: 8),
                                    Text('TTD'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(MdiIcons.folderOpenOutline),
                          label: const Text('Open', style: TextStyle(color: Colors.black)),
                          onPressed: () => OpenFile.open(widget.pdfFile.path),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secoundColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(MdiIcons.download),
                          label: const Text('Save As'),
                          onPressed: () async {
                            await _saveAsPdfFile(
                              context: context,
                              documentUseCases: documentUseCases,
                              sourcePdf: widget.pdfFile,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
