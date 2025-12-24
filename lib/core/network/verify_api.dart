import 'dart:convert';
import 'dart:io';

import '../errors/api_exception.dart';
import 'api_client.dart';

class VerifyApi {
  VerifyApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<VerifyResponse> verifyPdf({
    required String tenant,
    required File pdfFile,
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }
    if (!pdfFile.existsSync()) {
      throw const ApiException('File not found.');
    }

    final body = await _apiClient.postMultipart(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/verify'),
      fields: const <String, String>{},
      files: [
        ApiMultipartFile(
          field: 'file',
          file: pdfFile,
          contentType: 'application/pdf',
        ),
      ],
      defaultErrorMessage: 'Verify failed.',
    );

    final parsed = VerifyResponse.fromJsonString(body);

    final url = parsed.signedPdfDownloadUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return parsed.copyWith(
        signedPdfDownloadUrl: _apiClient.resolveUrl(url).toString(),
      );
    }

    return parsed;
  }
}

class VerifyResponse {
  const VerifyResponse({
    required this.valid,
    this.reason,
    this.documentId,
    this.chainId,
    this.versionNumber,
    this.signedPdfDownloadUrl,
    this.signedPdfSha256,
    this.expectedSignedPdfSha256,
    this.signatureValid,
    this.certificateStatus,
    this.rootCaFingerprint,
    this.certificateRevokedAt,
    this.certificateRevokedReason,
    this.tsaStatus,
    this.tsaSignedAt,
    this.tsaFingerprint,
    this.tsaReason,
    this.ltvStatus,
    this.ltvGeneratedAt,
    this.ltvIssues,
    this.signers,
  });

  final bool valid;
  final String? reason;
  final String? documentId;
  final String? chainId;
  final int? versionNumber;
  final String? signedPdfDownloadUrl;
  final String? signedPdfSha256;
  final String? expectedSignedPdfSha256;
  final bool? signatureValid;
  final String? certificateStatus;
  final String? rootCaFingerprint;
  final String? certificateRevokedAt;
  final String? certificateRevokedReason;

  /// TSA validation status.
  /// Known values: valid, invalid, missing.
  final String? tsaStatus;
  final String? tsaSignedAt;
  final String? tsaFingerprint;
  final String? tsaReason;

  /// LTV status.
  /// Known values: ready, incomplete, missing.
  final String? ltvStatus;
  final String? ltvGeneratedAt;
  final List<String>? ltvIssues;
  final List<Map<String, dynamic>>? signers;

  VerifyResponse copyWith({
    bool? valid,
    String? reason,
    String? documentId,
    String? chainId,
    int? versionNumber,
    String? signedPdfDownloadUrl,
    String? signedPdfSha256,
    String? expectedSignedPdfSha256,
    bool? signatureValid,
    String? certificateStatus,
    String? rootCaFingerprint,
    String? certificateRevokedAt,
    String? certificateRevokedReason,
    String? tsaStatus,
    String? tsaSignedAt,
    String? tsaFingerprint,
    String? tsaReason,
    String? ltvStatus,
    String? ltvGeneratedAt,
    List<String>? ltvIssues,
    List<Map<String, dynamic>>? signers,
  }) {
    return VerifyResponse(
      valid: valid ?? this.valid,
      reason: reason ?? this.reason,
      documentId: documentId ?? this.documentId,
      chainId: chainId ?? this.chainId,
      versionNumber: versionNumber ?? this.versionNumber,
      signedPdfDownloadUrl: signedPdfDownloadUrl ?? this.signedPdfDownloadUrl,
      signedPdfSha256: signedPdfSha256 ?? this.signedPdfSha256,
      expectedSignedPdfSha256:
          expectedSignedPdfSha256 ?? this.expectedSignedPdfSha256,
      signatureValid: signatureValid ?? this.signatureValid,
      certificateStatus: certificateStatus ?? this.certificateStatus,
      rootCaFingerprint: rootCaFingerprint ?? this.rootCaFingerprint,
      certificateRevokedAt: certificateRevokedAt ?? this.certificateRevokedAt,
      certificateRevokedReason:
          certificateRevokedReason ?? this.certificateRevokedReason,
      tsaStatus: tsaStatus ?? this.tsaStatus,
      tsaSignedAt: tsaSignedAt ?? this.tsaSignedAt,
      tsaFingerprint: tsaFingerprint ?? this.tsaFingerprint,
      tsaReason: tsaReason ?? this.tsaReason,
      ltvStatus: ltvStatus ?? this.ltvStatus,
      ltvGeneratedAt: ltvGeneratedAt ?? this.ltvGeneratedAt,
      ltvIssues: ltvIssues ?? this.ltvIssues,
      signers: signers ?? this.signers,
    );
  }

  static VerifyResponse fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ApiException('Invalid verify response.');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final rawValid = map['valid'];
    final valid = rawValid is bool ? rawValid : rawValid?.toString() == 'true';

    bool? signatureValid;
    final rawSignatureValid = map['signatureValid'];
    if (rawSignatureValid is bool) {
      signatureValid = rawSignatureValid;
    } else if (rawSignatureValid != null) {
      final parsed = rawSignatureValid.toString().trim().toLowerCase();
      if (parsed == 'true') signatureValid = true;
      if (parsed == 'false') signatureValid = false;
    }

    int? versionNumber;
    final rawVersion = map['versionNumber'];
    if (rawVersion is int) {
      versionNumber = rawVersion;
    } else if (rawVersion != null) {
      versionNumber = int.tryParse(rawVersion.toString());
    }

    List<Map<String, dynamic>>? signers;
    final rawSigners = map['signers'];
    if (rawSigners is List) {
      signers = rawSigners
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    List<String>? ltvIssues;
    final rawLtvIssues = map['ltvIssues'];
    if (rawLtvIssues is List) {
      ltvIssues = rawLtvIssues.map((e) => e.toString()).toList(growable: false);
    }

    return VerifyResponse(
      valid: valid,
      reason: map['reason']?.toString(),
      documentId: map['documentId']?.toString(),
      chainId: map['chainId']?.toString(),
      versionNumber: versionNumber,
      signedPdfDownloadUrl: map['signedPdfDownloadUrl']?.toString(),
      signedPdfSha256: map['signedPdfSha256']?.toString(),
      expectedSignedPdfSha256: map['expectedSignedPdfSha256']?.toString(),
      signatureValid: signatureValid,
      certificateStatus: map['certificateStatus']?.toString(),
      rootCaFingerprint: map['rootCaFingerprint']?.toString(),
      certificateRevokedAt: map['certificateRevokedAt']?.toString(),
      certificateRevokedReason: map['certificateRevokedReason']?.toString(),
      tsaStatus: map['tsaStatus']?.toString(),
      tsaSignedAt: map['tsaSignedAt']?.toString(),
      tsaFingerprint: map['tsaFingerprint']?.toString(),
      tsaReason: map['tsaReason']?.toString(),
      ltvStatus: map['ltvStatus']?.toString(),
      ltvGeneratedAt: map['ltvGeneratedAt']?.toString(),
      ltvIssues: ltvIssues,
      signers: signers,
    );
  }
}
