import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';

import '../../domain/usecases/document_usecases.dart';
import '../../utils/document_workspace.dart';
import '../../utils/pdf_file_name.dart';

Future<void> showVersionHistorySheet({
  required BuildContext context,
  required Directory workspaceDir,
}) async {
  final versions = DocumentWorkspace.listVersionsSync(workspaceDir);
  final originalName =
      await DocumentWorkspace.readOriginalName('${workspaceDir.path}/original.pdf');
  final baseName = PdfFileName.withoutPdfExtension(
    (originalName ?? 'document').trim(),
  );

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      if (versions.isEmpty) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No saved versions yet.'),
          ),
        );
      }

      return SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: versions.length,
          separatorBuilder: (_, _) => Divider(color: Colors.grey[300]),
          itemBuilder: (ctx, index) {
            final v = versions[index];
            return ListTile(
              leading: Icon(MdiIcons.filePdfBox, color: Colors.red[600]),
              title: Text('v${v.number}'),
              subtitle: Text(DocumentWorkspace.basename(v.file.path)),
              onTap: () => OpenFile.open(v.file.path),
              trailing: IconButton(
                tooltip: 'Save As',
                icon: Icon(MdiIcons.download),
                onPressed: () async {
                  final documentUseCases = ctx.read<DocumentUseCases>();
                  final suggested = '${baseName}__signed_v${v.number}.pdf';
                  final saved = await documentUseCases.savePdfToExternalStorage(
                    pdfFile: v.file,
                    fileName: PdfFileName.sanitizePdfFileName(suggested),
                  );
                  if (!ctx.mounted) return;
                  if (saved == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Save canceled.'),
                      ),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Saved: $saved'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    },
  );
}
