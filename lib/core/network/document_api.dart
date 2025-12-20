import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../errors/api_exception.dart';
import 'api_client.dart';

class DocumentApi {
  DocumentApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DocumentSignResponse> signDocument({
    required String tenant,
    required String accessToken,
    required File pdfFile,
    required bool consent,
  }) async {
    final t = tenant.trim();
    if (t.isEmpty) {
      throw const ApiException('Tenant is required.');
    }
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw const ApiException('Access token is required.');
    }
    if (!pdfFile.existsSync()) {
      throw const ApiException('File not found.');
    }

    final body = await _apiClient.postMultipart(
      uri: _apiClient.tenantUri(tenant: t, path: 'api/documents/sign'),
      fields: <String, String>{
        'consent': consent ? 'true' : 'false',
      },
      files: [
        ApiMultipartFile(
          field: 'file',
          file: pdfFile,
          contentType: 'application/pdf',
        ),
      ],
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $token',
      },
      defaultErrorMessage: 'Sign failed.',
    );

    return DocumentSignResponse.fromJsonString(body);
  }

  Future<Uint8List> downloadPdfBytes({required String url}) {
    final resolved = _apiClient.resolveUrl(url);
    return _apiClient.getBytes(
      uri: resolved,
      headers: <String, String>{
        HttpHeaders.acceptHeader: 'application/pdf',
      },
      defaultErrorMessage: 'Download failed.',
    );
  }
}

class DocumentSignResponse {
  const DocumentSignResponse({
    required this.documentId,
    required this.chainId,
    required this.versionNumber,
    required this.signedPdfDownloadUrl,
    required this.verificationUrl,
    this.signedPdfSha256,
    this.signers,
  });

  final String documentId;
  final String chainId;
  final int versionNumber;
  final String signedPdfDownloadUrl;
  final String verificationUrl;
  final String? signedPdfSha256;
  final List<Map<String, dynamic>>? signers;

  static DocumentSignResponse fromJsonString(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ApiException('Invalid sign response.');
    }
    final map = decoded.map((k, v) => MapEntry(k.toString(), v));

    final documentId = map['documentId']?.toString().trim();
    final chainId = map['chainId']?.toString().trim();

    int? versionNumber;
    final rawVersion = map['versionNumber'];
    if (rawVersion is int) {
      versionNumber = rawVersion;
    } else if (rawVersion != null) {
      versionNumber = int.tryParse(rawVersion.toString());
    }

    final signedPdfDownloadUrl = map['signedPdfDownloadUrl']?.toString().trim();
    final verificationUrl = map['verificationUrl']?.toString().trim();
    final signedPdfSha256 = map['signedPdfSha256']?.toString().trim();

    List<Map<String, dynamic>>? signers;
    final rawSigners = map['signers'];
    if (rawSigners is List) {
      signers = rawSigners
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    if (documentId == null || documentId.isEmpty) {
      throw const ApiException('Sign response missing documentId.');
    }
    if (chainId == null || chainId.isEmpty) {
      throw const ApiException('Sign response missing chainId.');
    }
    if (versionNumber == null || versionNumber < 1) {
      throw const ApiException('Sign response missing versionNumber.');
    }
    if (signedPdfDownloadUrl == null || signedPdfDownloadUrl.isEmpty) {
      throw const ApiException('Sign response missing signedPdfDownloadUrl.');
    }
    if (verificationUrl == null || verificationUrl.isEmpty) {
      throw const ApiException('Sign response missing verificationUrl.');
    }

    return DocumentSignResponse(
      documentId: documentId,
      chainId: chainId,
      versionNumber: versionNumber,
      signedPdfDownloadUrl: signedPdfDownloadUrl,
      verificationUrl: verificationUrl,
      signedPdfSha256: signedPdfSha256?.isEmpty == true ? null : signedPdfSha256,
      signers: signers,
    );
  }
}
