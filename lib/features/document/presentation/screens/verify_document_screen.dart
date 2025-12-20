import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/verify_api.dart';
import '../../utils/document_workspace.dart';
import '../widgets/document_verify_result_dialog.dart';
import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/field_label.dart';

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
  final TextEditingController _linkController = TextEditingController();

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

    final tenantId = widget.tenantController.text.trim();
    setState(() => _errorText = null);
    if (tenantId.isEmpty) {
      setState(() => _errorText = 'Tenant wajib diisi.');
      return;
    }

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
        tenantId: tenantId,
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

  ({String tenantId, String chainId, int versionNumber})? _parseVerifyLink(
    String input,
  ) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.length >= 5) {
      final s = uri.pathSegments;
      if (s.length >= 5 && s[1] == 'api' && s[2] == 'verify') {
        final tenant = s[0].trim();
        final chainId = s[3].trim();
        final v = s[4].trim();
        final version = v.startsWith('v') ? int.tryParse(v.substring(1)) : null;
        if (tenant.isNotEmpty && chainId.isNotEmpty && version != null) {
          return (tenantId: tenant, chainId: chainId, versionNumber: version);
        }
      }
    }

    final regex = RegExp(r'([A-Za-z0-9_-]{6,})\\s*/?\\s*v(\\d+)');
    final m = regex.firstMatch(raw);
    if (m != null) {
      final chainId = (m.group(1) ?? '').trim();
      final version = int.tryParse(m.group(2) ?? '');
      final tenantId = widget.tenantController.text.trim();
      if (tenantId.isNotEmpty && chainId.isNotEmpty && version != null) {
        return (tenantId: tenantId, chainId: chainId, versionNumber: version);
      }
    }

    return null;
  }

  Future<void> _verifyViaLink() async {
    if (_isChecking) return;

    setState(() => _errorText = null);
    final parts = _parseVerifyLink(_linkController.text);
    if (parts == null) {
      setState(
        () => _errorText = 'Link/QR tidak valid. Contoh: .../demo/api/verify/{chainId}/v1',
      );
      return;
    }

    if (widget.tenantController.text.trim() != parts.tenantId) {
      widget.tenantController.text = parts.tenantId;
    }

    setState(() => _isChecking = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final verifyApi = context.read<VerifyApi>();
      final check = await verifyApi.verifyByChain(
        tenant: parts.tenantId,
        chainId: parts.chainId,
        versionNumber: parts.versionNumber,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;

      await _persistTenant(parts.tenantId);
      if (!mounted) return;
      await showDocumentVerifyResultDialog(
        context: context,
        result: check,
        tenantId: parts.tenantId,
        fileName: null,
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

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.secoundColor, width: 1.6),
    );

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
        const FieldLabel(text: 'Tenant / Perusahaan'),
        const SizedBox(height: 6),
        TextField(
          controller: widget.tenantController,
          enabled: !_isChecking,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'contoh: demo',
            prefixIcon: const Icon(Icons.apartment_rounded),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1.2)),
            const SizedBox(width: 10),
            Text(
              'atau',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: Colors.grey[300], thickness: 1.2)),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel(text: 'Link / QR URL'),
        const SizedBox(height: 6),
        TextField(
          controller: _linkController,
          enabled: !_isChecking,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'tempel link verifikasi di sini',
            prefixIcon: const Icon(Icons.link_rounded),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
          ),
          onSubmitted: (_) => _verifyViaLink(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isChecking ? null : _verifyViaLink,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Verifikasi via Link/QR'),
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
