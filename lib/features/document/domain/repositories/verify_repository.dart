import '../entities/verify_result.dart';

abstract class VerifyRepository {
  Future<VerifyResult> verifyPdf({
    required String tenant,
    required String pdfPath,
  });
}

