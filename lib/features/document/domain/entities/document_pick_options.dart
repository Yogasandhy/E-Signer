class DocumentPickOptions {
  const DocumentPickOptions({
    this.allowedExtensions,
    this.allowMultiple = false,
  });

  final List<String>? allowedExtensions;
  final bool allowMultiple;
}

