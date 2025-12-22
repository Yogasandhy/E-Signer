import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/session_usecases.dart';
import '../../domain/usecases/verify_usecases.dart';
import '../../utils/document_workspace.dart';
import '../widgets/document_verify_result_dialog.dart';
import '../../../../presentation/app_theme.dart';

class VerifyDocumentScreen extends StatefulWidget {
  const VerifyDocumentScreen({
    super.key,
  });

  @override
  State<VerifyDocumentScreen> createState() => _VerifyDocumentScreenState();
}

class _VerifyDocumentScreenState extends State<VerifyDocumentScreen> {
  bool _isChecking = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _verifyUploadPdf() async {
    if (_isChecking) return;

    setState(() => _errorText = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    setState(() => _isChecking = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final verifyUseCases = context.read<VerifyUseCases>();
      final lastTenant = await context.read<SessionUseCases>().getLastTenant();
      final output = await verifyUseCases.verifyPdfAutoTenant(
        pdfPath: path,
        tenantHint: lastTenant,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;

      await showDocumentVerifyResultDialog(
        context: context,
        result: output.result,
        fileName: DocumentWorkspace.basename(path),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (!mounted) return;

      final message = (e is FormatException && e.message == 'Tenant not found.')
          ? 'Tenant tidak dapat dideteksi dari QR di PDF. Pastikan PDF memiliki QR verifikasi dari sistem ini (payload berisi /{tenant}/api/verify/{chainId}/v{version}).'
          : e.toString();

      setState(() => _errorText = message);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
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
