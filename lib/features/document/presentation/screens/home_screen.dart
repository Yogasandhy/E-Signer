import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:thumbnailer/thumbnailer.dart';

import '../../domain/entities/document_pick_options.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../domain/usecases/verify_usecases.dart';
import '../../utils/document_workspace.dart';
import '../../utils/pdf_validation.dart';
import '../bloc/recent_documents/recent_documents_bloc.dart';
import '../bloc/recent_documents/recent_documents_event.dart';
import '../bloc/recent_documents/recent_documents_state.dart';
import 'pdf_viewer_screen.dart';
import 'profile_screen.dart';
import '../widgets/document_verify_result_dialog.dart';
import '../../../../presentation/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.tenantId,
    required this.userId,
    required this.accessToken,
    this.userEmail,
    required this.onLogout,
  });

  final String tenantId;
  final String userId;
  final String accessToken;
  final String? userEmail;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DocumentUploadInformationWidget(
                tenantId: tenantId,
                userId: userId,
                userEmail: userEmail,
                onLogout: onLogout,
              ),
            ),
            Expanded(
              child: SelectedDocumentsWidget(
                tenantId: tenantId,
                userId: userId,
                accessToken: accessToken,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentUploadInformationWidget extends StatelessWidget {
  const DocumentUploadInformationWidget({
    super.key,
    required this.tenantId,
    required this.userId,
    this.userEmail,
    required this.onLogout,
  });

  final String tenantId;
  final String userId;
  final String? userEmail;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      color: AppTheme.secoundColor,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.upload_file_rounded,
                  color: Colors.white,
                  size: 150,
                ),
                const SizedBox(height: 20),
                const Text(
                  "You Need to Upload Your",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  "Document Files",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Make sure the file to be uploaded is correct \nand in PDF format (max ${DocumentPickOptions.defaultMaxFileSizeBytes ~/ (1024 * 1024)} MB)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    final path = result?.files.single.path;
                    if (path == null) return;

                    final pdfFile = File(path);
                    if (!context.mounted) return;

                    try {
                      await PdfValidation.validatePdfFile(
                        pdfFile,
                        maxBytes: DocumentPickOptions.defaultMaxFileSizeBytes,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      final raw = e.toString();
                      final message = raw.startsWith('Exception: ')
                          ? raw.substring('Exception: '.length)
                          : raw;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );

                    if (!context.mounted) return;
                    final verifyUseCases = context.read<VerifyUseCases>();
                    final check = await verifyUseCases.verifyPdf(
                      tenant: tenantId,
                      pdfPath: pdfFile.path,
                    );

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    if (!context.mounted) return;

                    await showDocumentVerifyResultDialog(
                      context: context,
                      fileName: DocumentWorkspace.basename(pdfFile.path),
                      result: check,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verifikasi Dokumen'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Profil',
              icon: const Icon(Icons.person_rounded, color: Colors.white),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      tenantId: tenantId,
                      userId: userId,
                      userEmail: userEmail,
                      onLogout: onLogout,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SelectedDocumentsWidget extends StatefulWidget {
  const SelectedDocumentsWidget({
    super.key,
    required this.tenantId,
    required this.userId,
    required this.accessToken,
  });

  final String tenantId;
  final String userId;
  final String accessToken;

  @override
  State<SelectedDocumentsWidget> createState() => _SelectedDocumentsWidgetState();
}

class _SelectedDocumentsWidgetState extends State<SelectedDocumentsWidget> {
  Future<void> _confirmAndDeletePermanently({
    required _RecentDocumentItem item,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus permanen?'),
            content: const Text(
              'Dokumen akan dihapus dari perangkat dan tidak bisa dikembalikan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !confirmed) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final workspaceDir = DocumentWorkspace.findWorkspaceDir(item.originalPath);
      if (workspaceDir != null && workspaceDir.existsSync()) {
        await workspaceDir.delete(recursive: true);
      } else {
        final file = File(item.originalPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context
        .read<RecentDocumentsBloc>()
        .add(RecentDocumentDeleted(item.originalPath));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen dihapus dari perangkat.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildRecentSection({
    required BuildContext context,
    required String title,
    required List<_RecentDocumentItem> items,
    required double cardWidth,
    required double gapResult,
    required double paddingCard,
  }) {
    final theme = Theme.of(context);

    final thumbHeight = MediaQuery.of(context).size.height * 0.17;
    final listHeight = thumbHeight + 70;

    final bool isHistory = title.toLowerCase().contains('history');
    final Color accentColor =
        isHistory ? Colors.green.shade700 : AppTheme.secoundColor;
    final IconData titleIcon =
        isHistory ? MdiIcons.checkDecagramOutline : MdiIcons.fileDocumentEditOutline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(titleIcon, color: accentColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accentColor.withAlpha(70)),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: (index == items.length - 1) ? paddingCard : gapResult,
                  left: (index == 0) ? paddingCard : 0,
                  top: 10,
                ),
                child: Column(
                  children: [
                    Material(
                      elevation: 6,
                      color: Colors.white,
                      shadowColor: Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                      key: ValueKey(item.originalPath),
                      onTap: () async {
                        context
                            .read<RecentDocumentsBloc>()
                            .add(RecentDocumentSelected(item.originalPath));
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              pdfFile: item.displayFile,
                              mode: item.isSigned
                                  ? PdfViewerMode.signedResult
                                  : PdfViewerMode.preview,
                              verificationUrl: item.verificationUrl,
                              tenantId: widget.tenantId,
                              userId: widget.userId,
                              accessToken: widget.accessToken,
                            ),
                          ),
                        );
                        if (!mounted) return;
                        setState(() {});
                      },
                      child: SizedBox(
                        height: thumbHeight,
                        width: cardWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _RecentPdfThumbnail(
                              pdfFile: item.displayFile,
                              widgetSize: thumbHeight,
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (item.isSigned
                                          ? Colors.green.shade700
                                          : AppTheme.secoundColor)
                                      .withAlpha(220),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.isSigned ? 'SIGNED' : 'DRAFT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Material(
                                color: Colors.black.withAlpha(110),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _confirmAndDeletePermanently(
                                    item: item,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                    Container(
                      width: cardWidth,
                      margin: const EdgeInsets.only(top: 10),
                      alignment: Alignment.center,
                      child: FutureBuilder<String>(
                        future: DocumentWorkspace.resolveDisplayName(
                          item.originalPath,
                        ),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ??
                                DocumentWorkspace.basename(item.originalPath),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentUseCases = context.read<DocumentUseCases>();

    final double screenWidth =
        MediaQuery.of(context).size.width; // screen width
    const double paddingCard = 16; // predefined padding for card
    const double totalPadding = paddingCard * 2; // predefined total padding
    const double totalCard = 3; // total card you want to display
    const double totalGap = 2; // total gap between cards
    final double cardWidth = screenWidth * 0.25; // displayed card size
    final double totalCardWidth = cardWidth * totalCard; // total card size
    final double gapResult = (screenWidth - totalPadding - totalCardWidth) /
        totalGap; // gap between cards

    return BlocBuilder<RecentDocumentsBloc, RecentDocumentsState>(
      builder: (context, state) {
        final recentItems = state.documentPath
            .map(
              (originalPath) {
                final displayFile =
                    DocumentWorkspace.resolveLatestPdfSync(originalPath);
                final isSigned = displayFile.path != originalPath;
                final verificationUrl = isSigned
                    ? DocumentWorkspace.readBackendVerificationUrlSync(
                        originalPath,
                      )
                    : null;
                return _RecentDocumentItem(
                  originalPath: originalPath,
                  displayFile: displayFile,
                  isSigned: isSigned,
                  verificationUrl: verificationUrl,
                );
              },
            )
            .toList(growable: false);

        final drafts =
            recentItems.where((item) => !item.isSigned).toList(growable: false);
        final history =
            recentItems.where((item) => item.isSigned).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: state.documentPath.isNotEmpty
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  String? picked;
                  try {
                    picked = await documentUseCases.pickDocument(
                      tenantId: widget.tenantId,
                      userId: widget.userId,
                      options: const DocumentPickOptions(
                        allowedExtensions: ['pdf'],
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    final raw = e.toString();
                    final message = raw.startsWith('Exception: ')
                        ? raw.substring('Exception: '.length)
                        : raw;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!context.mounted) return;

                  final pickedPath = picked;
                  if (pickedPath != null) {
                    context
                        .read<RecentDocumentsBloc>()
                        .add(RecentDocumentAdded(pickedPath));
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          pdfFile: File(pickedPath),
                          mode: PdfViewerMode.preview,
                          tenantId: widget.tenantId,
                          userId: widget.userId,
                          accessToken: widget.accessToken,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    setState(() {});
                  }
                },
                child: Container(
                  height: state.documentPath.isNotEmpty ? 80 : 200,
                  width: double.infinity,
                  margin: const EdgeInsets.all(16.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.secoundColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.secoundColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        MdiIcons.fileDocumentOutline,
                        color: AppTheme.secoundColor,
                        size: 60,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select the document from \nyour device',
                            style: TextStyle(
                              color: AppTheme.secoundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'PDF Only (max ${DocumentPickOptions.defaultMaxFileSizeBytes ~/ (1024 * 1024)} MB)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.documentPath.isNotEmpty)
              Expanded(
                child: ListView(
                  children: [
                    if (drafts.isNotEmpty)
                      _buildRecentSection(
                        context: context,
                        title: 'Draft',
                        items: drafts,
                        cardWidth: cardWidth,
                        gapResult: gapResult,
                        paddingCard: paddingCard,
                      ),
                    if (history.isNotEmpty)
                      _buildRecentSection(
                        context: context,
                        title: 'History',
                        items: history,
                        cardWidth: cardWidth,
                        gapResult: gapResult,
                        paddingCard: paddingCard,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentDocumentItem {
  const _RecentDocumentItem({
    required this.originalPath,
    required this.displayFile,
    required this.isSigned,
    required this.verificationUrl,
  });

  final String originalPath;
  final File displayFile;
  final bool isSigned;
  final String? verificationUrl;
}

class _RecentPdfThumbnail extends StatelessWidget {
  const _RecentPdfThumbnail({
    required this.pdfFile,
    required this.widgetSize,
  });

  final File pdfFile;
  final double widgetSize;

  @override
  Widget build(BuildContext context) {
    return Thumbnail(
      key: ValueKey(pdfFile.path),
      dataResolver: () async => pdfFile.readAsBytes(),
      mimeType: 'application/pdf',
      widgetSize: widgetSize,
    );
  }
}
