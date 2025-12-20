class PdfFileName {
  static String withoutPdfExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  static String sanitizePdfFileName(String input) {
    var name = input.trim();
    name = name.replaceAll(RegExp(r'[\\\\/:*?\"<>|]'), '_');
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    return name;
  }

  static int? tryParseVersionNumber(String fileName) {
    final match = RegExp(r'^v(\\d+)\\.pdf$', caseSensitive: false).firstMatch(
      fileName.trim(),
    );
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }
}

