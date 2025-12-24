import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../domain/entities/document_signer.dart';
import '../../domain/entities/verify_result.dart';
import '../../domain/usecases/tenant_usecases.dart';
import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/dialog.dart';

Future<void> showDocumentVerifyResultDialog({
  required BuildContext context,
  String? fileName,
  required VerifyResult result,
}) async {
  final theme = Theme.of(context);

  String buildInvalidSubtitle() {
    final reason = (result.reason ?? '').trim();
    if (reason.isEmpty) {
      return 'Dokumen tidak valid atau sudah berubah.';
    }

    return switch (reason) {
      'hash_not_found' => 'Dokumen tidak terdaftar di server.',
      'hash_mismatch' => 'Dokumen berubah (hash mismatch).',
      _ => 'Dokumen tidak valid ($reason).',
    };
  }

  final ui = result.valid
      ? _VerifyUi(
          title: 'VALID',
          subtitle: 'Dokumen valid menurut sistem verifikasi.',
          icon: MdiIcons.shieldCheckOutline,
          color: Colors.green,
        )
      : _VerifyUi(
          title: 'TIDAK VALID',
          subtitle: buildInvalidSubtitle(),
          icon: MdiIcons.shieldAlertOutline,
          color: Colors.red,
        );

  final signers = result.signers;

  final tenantNames = signers.isEmpty
      ? const <String, String>{}
      : await _resolveTenantNames(context: context, signers: signers);
  if (!context.mounted) return;

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
          if ((fileName ?? '').trim().isNotEmpty) ...[
            _KeyValue(label: 'File', value: fileName!.trim()),
            const SizedBox(height: 10),
          ],
          if (result.versionNumber != null) ...[
            _KeyValue(label: 'Versi', value: 'v${result.versionNumber}'),
            const SizedBox(height: 10),
          ],
          if (result.signatureValid != null) ...[
            _KeyValue(
              label: 'Signature',
              value: result.signatureValid == true ? 'VALID' : 'TIDAK VALID',
            ),
            const SizedBox(height: 10),
          ],
          if ((result.certificateStatus ?? '').trim().isNotEmpty) ...[
            _KeyValue(
              label: 'Sertifikat',
              value: _formatCertificateStatus(result.certificateStatus!),
            ),
            const SizedBox(height: 10),
          ],
          if ((result.tsaStatus ?? '').trim().isNotEmpty) ...[
            _KeyValue(
              label: 'TSA',
              value: _formatTsaStatus(
                rawStatus: result.tsaStatus!,
                rawReason: result.tsaReason,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if ((result.ltvStatus ?? '').trim().isNotEmpty) ...[
            _KeyValue(
              label: 'LTV',
              value: _formatLtvStatus(
                rawStatus: result.ltvStatus!,
                issueCount: result.ltvIssues.length,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (signers.isNotEmpty)
            _SignerHistoryBox(
              signers: signers,
              tenantNames: tenantNames,
            ),
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

class _SignerHistoryBox extends StatelessWidget {
  const _SignerHistoryBox({
    required this.signers,
    required this.tenantNames,
  });

  final List<DocumentSigner> signers;
  final Map<String, String> tenantNames;

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
            'Penandatangan',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.secoundColor,
            ),
          ),
          const SizedBox(height: 8),
          ...(() {
            final groups = <String, List<DocumentSigner>>{};
            final order = <String>[];

            for (final signer in signers) {
              final rawTenant = signer.tenantId.trim();
              final tenant = rawTenant.isNotEmpty ? rawTenant : 'Tenant';
              final list = groups.putIfAbsent(tenant, () {
                order.add(tenant);
                return <DocumentSigner>[];
              });
              list.add(signer);
            }

            final widgets = <Widget>[];

            for (var i = 0; i < order.length; i++) {
              final tenant = order[i];
              final tenantSigners = groups[tenant] ?? const <DocumentSigner>[];
              final resolvedTenantName =
                  (tenantNames[tenant] ?? tenant).trim().isEmpty
                      ? 'Tenant'
                      : (tenantNames[tenant] ?? tenant).trim();

              widgets.add(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secoundColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppTheme.secoundColor.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apartment_rounded,
                        size: 14,
                        color: AppTheme.secoundColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        resolvedTenantName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.secoundColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(const SizedBox(height: 8));

              for (final s in tenantSigners) {
                final index = s.index.toString();
                final userId = s.userId;
                final name = (s.name ?? '').trim();
                final email = (s.email ?? '').trim();
                final displayName = name.isNotEmpty ? name : userId;

                widgets.add(
                  Padding(
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
                                displayName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
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
                  ),
                );
              }

              if (i != order.length - 1) {
                widgets.add(const SizedBox(height: 10));
              }
            }

            return widgets;
          })(),
        ],
      ),
    );
  }
}

String _formatCertificateStatus(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;
  return switch (v) {
    'valid' => 'Valid',
    'expired' => 'Expired',
    'revoked' => 'Revoked',
    'untrusted' => 'Untrusted',
    'not_yet_valid' => 'Not yet valid',
    'missing' => 'Missing',
    _ => v,
  };
}

String _formatTsaStatus({
  required String rawStatus,
  String? rawReason,
}) {
  final status = rawStatus.trim();
  if (status.isEmpty) return status;

  final label = switch (status) {
    'valid' => 'Valid',
    'invalid' => 'Invalid',
    'missing' => 'Missing',
    _ => status,
  };

  final reason = (rawReason ?? '').trim();
  if (reason.isEmpty || status == 'valid') return label;
  return '$label ($reason)';
}

String _formatLtvStatus({
  required String rawStatus,
  required int issueCount,
}) {
  final status = rawStatus.trim();
  if (status.isEmpty) return status;

  final label = switch (status) {
    'ready' => 'Ready',
    'incomplete' => 'Incomplete',
    'missing' => 'Missing',
    _ => status,
  };

  if (issueCount <= 0 || status == 'ready') return label;
  return '$label ($issueCount masalah)';
}

Future<Map<String, String>> _resolveTenantNames({
  required BuildContext context,
  required List<DocumentSigner> signers,
}) async {
  final tenantUseCases = context.read<TenantUseCases>();
  final tenantKeys = signers
      .map((s) => s.tenantId.trim())
      .where((t) => t.isNotEmpty)
      .toSet();
  if (tenantKeys.isEmpty) return const <String, String>{};

  final entries = await Future.wait(
    tenantKeys.map((t) async {
      try {
        final info = await tenantUseCases.getPublicInfo(tenant: t).timeout(
              const Duration(seconds: 6),
            );
        return MapEntry(t, info.name.trim());
      } catch (_) {
        return MapEntry(t, t);
      }
    }),
  );

  final resolved = <String, String>{};
  for (final entry in entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      resolved[entry.key] = value;
    }
  }
  return resolved;
}
