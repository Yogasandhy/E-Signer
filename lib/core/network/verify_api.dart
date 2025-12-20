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

    return VerifyResponse.fromJsonString(body);
  }

  Future<VerifyResponse> verifyByChain({
    required String tenant,
    required String chainId,
    required int versionNumber,
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }
    final c = chainId.trim();
    if (c.isEmpty) {
      throw const ApiException('chainId is required.');
    }
    if (versionNumber < 1) {
      throw const ApiException('versionNumber must be >= 1.');
    }

    final body = await _apiClient.getJson(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/verify/$c/v$versionNumber'),
      defaultErrorMessage: 'Verify failed.',
    );

    final parsed = VerifyResponse.fromJsonString(body);
    return parsed.copyWith(
      chainId: (parsed.chainId == null || parsed.chainId!.trim().isEmpty)
          ? c
          : parsed.chainId,
      versionNumber: parsed.versionNumber ?? versionNumber,
    );
  }
}

class VerifyResponse {
  const VerifyResponse({
    required this.valid,
    this.documentId,
    this.chainId,
    this.versionNumber,
    this.signedPdfDownloadUrl,
    this.signedPdfSha256,
    this.signers,
  });

  final bool valid;
  final String? documentId;
  final String? chainId;
  final int? versionNumber;
  final String? signedPdfDownloadUrl;
  final String? signedPdfSha256;
  final List<Map<String, dynamic>>? signers;

  VerifyResponse copyWith({
    bool? valid,
    String? documentId,
    String? chainId,
    int? versionNumber,
    String? signedPdfDownloadUrl,
    String? signedPdfSha256,
    List<Map<String, dynamic>>? signers,
  }) {
    return VerifyResponse(
      valid: valid ?? this.valid,
      documentId: documentId ?? this.documentId,
      chainId: chainId ?? this.chainId,
      versionNumber: versionNumber ?? this.versionNumber,
      signedPdfDownloadUrl: signedPdfDownloadUrl ?? this.signedPdfDownloadUrl,
      signedPdfSha256: signedPdfSha256 ?? this.signedPdfSha256,
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

    return VerifyResponse(
      valid: valid,
      documentId: map['documentId']?.toString(),
      chainId: map['chainId']?.toString(),
      versionNumber: versionNumber,
      signedPdfDownloadUrl: map['signedPdfDownloadUrl']?.toString(),
      signedPdfSha256: map['signedPdfSha256']?.toString(),
      signers: signers,
    );
  }
}
