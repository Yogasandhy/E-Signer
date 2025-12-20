import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/network/verify_api.dart';
import '../../domain/entities/document_signer.dart';
import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/dialog.dart';

Future<void> showDocumentVerifyResultDialog({
  required BuildContext context,
  String? tenantId,
  String? fileName,
  required VerifyResponse result,
}) async {
  final theme = Theme.of(context);

  final ui = result.valid
      ? _VerifyUi(
          title: 'VALID',
          subtitle: 'Dokumen valid menurut sistem verifikasi.',
          icon: MdiIcons.shieldCheckOutline,
          color: Colors.green,
        )
      : _VerifyUi(
          title: 'TIDAK VALID',
          subtitle: 'Dokumen tidak valid atau sudah berubah.',
          icon: MdiIcons.shieldAlertOutline,
          color: Colors.red,
        );

  final signers = <DocumentSigner>[];
  final rawSigners = result.signers;
  if (rawSigners != null) {
    for (final entry in rawSigners) {
      final signer = DocumentSigner.fromJson(entry);
      if (signer != null) signers.add(signer);
    }
  }

  await showCustomDialog<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ui.color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(ui.icon, color: ui.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifikasi Dokumen',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ui.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ui.color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ui.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 10),
          if ((tenantId ?? '').trim().isNotEmpty) ...[
            _KeyValue(label: 'Tenant', value: tenantId!.trim()),
            const SizedBox(height: 10),
          ],
          if ((fileName ?? '').trim().isNotEmpty) ...[
            _KeyValue(label: 'File', value: fileName!.trim()),
            const SizedBox(height: 10),
          ],
          if ((result.documentId ?? '').trim().isNotEmpty) ...[
            _KeyValue(label: 'Dokumen', value: result.documentId!.trim()),
            const SizedBox(height: 10),
          ],
          if ((result.chainId ?? '').trim().isNotEmpty) ...[
            _KeyValue(label: 'Chain', value: result.chainId!.trim()),
            const SizedBox(height: 10),
          ],
          if (result.versionNumber != null) ...[
            _KeyValue(label: 'Versi', value: 'v${result.versionNumber}'),
            const SizedBox(height: 10),
          ],
          if ((result.signedPdfDownloadUrl ?? '').trim().isNotEmpty) ...[
            _CopyBox(
              label: 'Download URL',
              value: result.signedPdfDownloadUrl!.trim(),
              onCopy: () async {
                await Clipboard.setData(
                  ClipboardData(text: result.signedPdfDownloadUrl!.trim()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          if ((result.signedPdfSha256 ?? '').trim().isNotEmpty) ...[
            _HashBox(
              sha256Hex: result.signedPdfSha256!.trim(),
              onCopy: () async {
                await Clipboard.setData(
                  ClipboardData(text: result.signedPdfSha256!.trim()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SHA-256 copied')),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          if (signers.isNotEmpty) _SignerHistoryBox(signers: signers),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secoundColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VerifyUi {
  const _VerifyUi({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _CopyBox extends StatelessWidget {
  const _CopyBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                icon: Icon(MdiIcons.contentCopy, size: 18),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _HashBox extends StatelessWidget {
  const _HashBox({
    required this.sha256Hex,
    required this.onCopy,
  });

  final String sha256Hex;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SHA-256',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                icon: Icon(MdiIcons.contentCopy, size: 18),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            sha256Hex,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignerHistoryBox extends StatelessWidget {
  const _SignerHistoryBox({required this.signers});

  final List<DocumentSigner> signers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secoundColor.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secoundColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Tanda Tangan',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.secoundColor,
            ),
          ),
          const SizedBox(height: 8),
          ...signers.map((s) {
            final index = s.index.toString();
            final tenantId = s.tenantId;
            final userId = s.userId;
            final signedAtIso = s.signedAtIso;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.secoundColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      index,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.secoundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tenantId • $userId',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (signedAtIso.trim().isNotEmpty)
                          Text(
                            signedAtIso.replaceFirst('T', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
