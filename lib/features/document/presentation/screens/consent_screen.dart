import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/api_exception.dart';
import '../../domain/entities/document_signing_result.dart';
import '../../domain/usecases/document_usecases.dart';
import '../../utils/document_workspace.dart';
import '../../../../presentation/app_theme.dart';
import 'pdf_viewer_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.originalPdf,
    required this.tenantId,
    required this.userId,
    required this.accessToken,
  });

  final File originalPdf;
  final String tenantId;
  final String userId;
  final String accessToken;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consentChecked = false;
  bool _isSubmitting = false;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
  }

  Future<void> _onSignPressed() async {
    if (_isSubmitting || !_consentChecked) return;

    setState(() => _isSubmitting = true);
    final documentUseCases = context.read<DocumentUseCases>();

    debugPrint(
      'SignDocument: start tenant=${widget.tenantId} userId=${widget.userId} file=${widget.originalPdf.path} idempotencyKey=$_idempotencyKey',
    );

    DocumentSigningResult? result;
    try {
      result = await documentUseCases.requestDocumentSigning(
        originalPdfPath: widget.originalPdf.path,
        tenantId: widget.tenantId,
        accessToken: widget.accessToken,
        userId: widget.userId,
        consent: true,
        idempotencyKey: _idempotencyKey,
      );
    } catch (e, st) {
      debugPrint('SignDocument: failed error=$e');
      if (e is ApiException) {
        debugPrint('SignDocument: httpStatus=${e.statusCode}');
        final details = e.details;
        if (details != null) {
          final text = details.toString();
          const maxLen = 1200;
          final snippet = text.length <= maxLen ? text : text.substring(0, maxLen);
          debugPrint('SignDocument: details(${text.length} chars)=$snippet');
        }
      }
      debugPrint('SignDocument: stack=$st');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal signing. Coba lagi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final signed = result;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfFile: File(signed.signedPdfPath),
          mode: PdfViewerMode.signedResult,
          verificationUrl: signed.verificationUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalName =
        DocumentWorkspace.basename(widget.originalPdf.path).trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consent'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dokumen',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                originalName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                'Pernyataan',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Saya menyetujui untuk menandatangani dokumen ini. '
                    'Saya memahami bahwa proses penandatanganan dilakukan oleh sistem '
                    '(backend) dan dokumen yang dihasilkan akan disimpan sebagai versi baru.',
                    style: TextStyle(color: Colors.grey[900], height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentChecked,
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() => _consentChecked = value ?? false),
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
                  ),
                  onPressed: (_consentChecked && !_isSubmitting)
                      ? _onSignPressed
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tanda Tangani'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
