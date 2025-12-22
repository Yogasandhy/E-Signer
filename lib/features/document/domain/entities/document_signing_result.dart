import 'package:equatable/equatable.dart';

class DocumentSigningResult extends Equatable {
  const DocumentSigningResult({
    required this.signedPdfPath,
    required this.versionNumber,
    this.verificationUrl,
  });

  final String signedPdfPath;
  final int versionNumber;
  final String? verificationUrl;

  @override
  List<Object?> get props => [signedPdfPath, versionNumber, verificationUrl];
}
