import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:thumbnailer/thumbnailer.dart';

import '../../../../core/network/verify_api.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../utils/document_workspace.dart';
import '../bloc/recent_documents/recent_documents_bloc.dart';
import '../bloc/recent_documents/recent_documents_event.dart';
import '../bloc/recent_documents/recent_documents_state.dart';
import 'pdf_viewer_screen.dart';
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
                  "Make sure the file to be uploaded is correct \nand in PDF format",
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

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );

                    final verifyApi = context.read<VerifyApi>();
                    final check = await verifyApi.verifyPdf(
                      tenant: tenantId,
                      pdfFile: pdfFile,
                    );

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    if (!context.mounted) return;

                    await showDocumentVerifyResultDialog(
                      context: context,
                      tenantId: tenantId,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.55,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$tenantId • ${(userEmail ?? userId).trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text(
                          'Kamu akan keluar dan bisa login dengan akun lain.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Logout', style: TextStyle(color: Colors.black),),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    await onLogout();
                  },
                ),
              ],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: state.documentPath.isNotEmpty
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final picked = await documentUseCases.pickDocument(
                    tenantId: widget.tenantId,
                    userId: widget.userId,
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );

                  if (!context.mounted) return;

                  if (picked != null) {
                    context
                        .read<RecentDocumentsBloc>()
                        .add(RecentDocumentAdded(picked.path));
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          pdfFile: picked,
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
                            'PDF Only',
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
            if (state.documentPath.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 55,
                    child: Divider(
                      color: Colors.grey[300],
                      thickness: 1.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Recent File',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 55,
                    child: Divider(
                      color: Colors.grey[300],
                      thickness: 1.5,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: state.documentPath.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                      right: (index == state.documentPath.length - 1)
                          ? paddingCard
                          : gapResult,
                      left: (index == 0) ? paddingCard : 0,
                      top: 25,
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          key: ValueKey(state.documentPath[index]),
                          onTap: () async {
                            final displayFile = DocumentWorkspace.resolveLatestPdfSync(
                              state.documentPath[index],
                            );
                            context
                                .read<RecentDocumentsBloc>()
                                .add(RecentDocumentSelected(state.documentPath[index]));
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfViewerScreen(
                                  pdfFile: displayFile,
                                  mode: PdfViewerMode.preview,
                                  tenantId: widget.tenantId,
                                  userId: widget.userId,
                                  accessToken: widget.accessToken,
                                ),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {});
                          },
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.17,
                            width: cardWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black),
                            ),
                            child: _RecentPdfThumbnail(
                              pdfFile: DocumentWorkspace.resolveLatestPdfSync(
                                state.documentPath[index],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: cardWidth,
                          margin: const EdgeInsets.only(top: 10),
                          alignment: Alignment.center,
                          child: FutureBuilder<String>(
                            future: DocumentWorkspace.resolveDisplayName(
                              state.documentPath[index],
                            ),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ??
                                    DocumentWorkspace.basename(state.documentPath[index]),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        );
      },
    );
  }
}

class _RecentPdfThumbnail extends StatelessWidget {
  const _RecentPdfThumbnail({required this.pdfFile});

  final File pdfFile;

  @override
  Widget build(BuildContext context) {
    return Thumbnail(
      key: ValueKey(pdfFile.path),
      dataResolver: () async => pdfFile.readAsBytes(),
      mimeType: 'application/pdf',
      widgetSize: MediaQuery.of(context).size.height * 0.19,
    );
  }
}
