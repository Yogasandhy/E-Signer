import 'dart:convert';
import 'dart:io';

class WorkspaceVersion {
  const WorkspaceVersion({
    required this.number,
    required this.file,
  });

  final int number;
  final File file;
}

class DocumentWorkspace {
  static const String _docPrefix = 'doc_';

  static String basename(String path) => path.split(RegExp(r'[/\\\\]')).last;

  static Directory? findWorkspaceDir(String anyPath) {
    var dir = File(anyPath).parent;
    while (true) {
      final name = basename(dir.path);
      if (name.startsWith(_docPrefix)) return dir;

      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  static File metaFile(Directory workspaceDir) =>
      File('${workspaceDir.path}/meta.json');

  static Directory versionsDir(Directory workspaceDir) =>
      Directory('${workspaceDir.path}/versions');

  static File versionFile(Directory workspaceDir, int versionNumber) =>
      File('${versionsDir(workspaceDir).path}/v$versionNumber.pdf');

  static Future<String?> readOriginalName(String documentPath) async {
    final workspaceDir = findWorkspaceDir(documentPath);
    if (workspaceDir == null) return null;

    final file = metaFile(workspaceDir);
    if (!file.existsSync()) return null;

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final name = json['originalName'] as String?;
      if (name == null || name.trim().isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }

  static List<WorkspaceVersion> listVersionsSync(Directory workspaceDir) {
    final dir = versionsDir(workspaceDir);
    if (!dir.existsSync()) return const [];

    final regex = RegExp(r'^v(\\d+)\\.pdf$', caseSensitive: false);
    final versions = <WorkspaceVersion>[];

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      final match = regex.firstMatch(name);
      if (match == null) continue;
      final n = int.tryParse(match.group(1) ?? '');
      if (n == null) continue;
      versions.add(WorkspaceVersion(number: n, file: entity));
    }

    versions.sort((a, b) => b.number.compareTo(a.number));
    return versions;
  }

  static File? latestVersionSync(Directory workspaceDir) {
    final versions = listVersionsSync(workspaceDir);
    if (versions.isEmpty) return null;
    return versions.first.file;
  }
}
