import '../entities/verify_result.dart';
import '../repositories/session_repository.dart';
import '../repositories/verify_repository.dart';
import '../services/tenant_detector.dart';

class VerifyUseCases {
  VerifyUseCases({
    required VerifyRepository verifyRepository,
    required TenantDetector tenantDetector,
    required SessionRepository sessionRepository,
  })  : _verifyRepository = verifyRepository,
        _tenantDetector = tenantDetector,
        _sessionRepository = sessionRepository;

  final VerifyRepository _verifyRepository;
  final TenantDetector _tenantDetector;
  final SessionRepository _sessionRepository;

  Future<VerifyResult> verifyPdf({
    required String tenant,
    required String pdfPath,
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const FormatException('Tenant is required.');
    }

    return _verifyRepository.verifyPdf(
      tenant: t,
      pdfPath: pdfPath,
    );
  }

  Future<({String tenant, VerifyResult result})> verifyPdfAutoTenant({
    required String pdfPath,
    String? tenantHint,
  }) async {
    final hint = (tenantHint ?? '').trim();
    final detected =
        (await _tenantDetector.detectTenantFromPdf(pdfPath: pdfPath))?.trim() ??
            '';
    final resolvedTenant = detected.isNotEmpty ? detected : hint;
    if (resolvedTenant.trim().isEmpty) {
      throw const FormatException('Tenant not found.');
    }

    final result = await verifyPdf(tenant: resolvedTenant, pdfPath: pdfPath);
    await _sessionRepository.setLastTenant(resolvedTenant);
    return (tenant: resolvedTenant, result: result);
  }
}

