import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/usecases/document_usecases.dart';
import '../../utils/document_workspace.dart';
import 'consent_screen.dart';
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
  });

  final File pdfFile;
  final PdfViewerMode mode;
  final String? verificationUrl;
  final String? tenantId;
  final String? userId;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _pdfViewerCtrl;

  @override
  void initState() {
    super.initState();
    _pdfViewerCtrl = PdfViewerController();
  }

  Future<void> _saveAsPdfFile({
    required BuildContext context,
    required DocumentUseCases documentUseCases,
    required File sourcePdf,
  }) async {
    final suggested = await _suggestedSaveFileName(sourcePdf);

    final sanitized = _sanitizePdfFileName(suggested);
    final saved = await documentUseCases.savePdfToExternalStorage(
      pdfFile: sourcePdf,
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
        _tryParseVersionNumber(DocumentWorkspace.basename(sourcePdf.path));
    if (versionNumber == null) return _sanitizePdfFileName(originalName);

    final base = _withoutPdfExtension(originalName.trim());
    return '${base}__signed_v$versionNumber.pdf';
  }

  int? _tryParseVersionNumber(String fileName) {
    final match = RegExp(r'^v(\d+)\.pdf$', caseSensitive: false).firstMatch(
      fileName.trim(),
    );
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  String _withoutPdfExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  String _sanitizePdfFileName(String input) {
    var name = input.trim();
    name = name.replaceAll(RegExp(r'[\\\\/:*?\"<>|]'), '_');
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final documentUseCases = context.read<DocumentUseCases>();
    final title = switch (widget.mode) {
      PdfViewerMode.preview => 'Preview Dokumen',
      PdfViewerMode.signedResult => 'Hasil Tanda Tangan',
    };

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
                params: const PdfViewerParams(
                  scaleEnabled: true,
                ),
              ),
            ),
            if (widget.mode == PdfViewerMode.preview) ...[
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secoundColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(MdiIcons.checkDecagramOutline),
                      label: const Text('Lanjut ke Consent'),
                      onPressed: () async {
                        final userId = widget.userId?.trim();
                        final tenantId = widget.tenantId?.trim();
                        if (tenantId == null ||
                            tenantId.isEmpty ||
                            userId == null ||
                            userId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User belum login.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConsentScreen(
                              originalPdf: widget.pdfFile,
                              tenantId: tenantId,
                              userId: userId,
                            ),
                          ),
                        );
                      },
                    ),
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
