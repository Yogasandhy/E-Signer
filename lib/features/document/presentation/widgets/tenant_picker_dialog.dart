import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../domain/entities/tenant_membership.dart';
import '../../../../presentation/app_theme.dart';

Future<TenantMembership?> showTenantPickerDialog({
  required BuildContext context,
  required List<TenantMembership> tenants,
}) {
  final allItems = tenants
      .where((t) => t.slug.trim().isNotEmpty && t.name.trim().isNotEmpty)
      .toList(growable: false);

  return showDialog<TenantMembership>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      String query = '';

      List<TenantMembership> filtered() {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return allItems;
        return allItems
            .where(
              (t) =>
                  t.name.toLowerCase().contains(q) ||
                  t.slug.toLowerCase().contains(q) ||
                  (t.role ?? '').toLowerCase().contains(q),
            )
            .toList(growable: false);
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final items = filtered();
          final theme = Theme.of(context);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.secoundColor.withAlpha(18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            MdiIcons.domain,
                            color: AppTheme.secoundColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Tenant',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih tenant yang ingin kamu masuki.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari tenant (nama / slug / role)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppTheme.secoundColor,
                            width: 1.6,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Colors.transparent,
                          child: items.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Tenant tidak ditemukan.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
                                  itemBuilder: (ctx, index) {
                                    final tenant = items[index];
                                    final role = (tenant.role ?? '').trim();

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            AppTheme.secoundColor.withAlpha(18),
                                        child: Icon(
                                          MdiIcons.officeBuildingOutline,
                                          color: AppTheme.secoundColor,
                                        ),
                                      ),
                                      title: Text(
                                        tenant.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        role.isEmpty
                                            ? tenant.slug
                                            : '${tenant.slug} • $role',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                      trailing:
                                          const Icon(Icons.chevron_right_rounded),
                                      onTap: () => Navigator.pop(ctx, tenant),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

