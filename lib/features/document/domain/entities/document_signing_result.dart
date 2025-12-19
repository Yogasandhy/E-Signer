import 'dart:io';

import 'package:equatable/equatable.dart';

class DocumentSigningResult extends Equatable {
  const DocumentSigningResult({
    required this.signedPdf,
    required this.versionNumber,
    this.verificationUrl,
  });

  final File signedPdf;
  final int versionNumber;
  final String? verificationUrl;

  @override
  List<Object?> get props => [signedPdf.path, versionNumber, verificationUrl];
}

