class DocumentPickOptions {
  static const int defaultMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  const DocumentPickOptions({
    this.allowedExtensions,
    this.allowMultiple = false,
    this.maxFileSizeBytes = defaultMaxFileSizeBytes,
  });

  final List<String>? allowedExtensions;
  final bool allowMultiple;
  final int maxFileSizeBytes;
}
