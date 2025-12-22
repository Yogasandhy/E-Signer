import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/auth_api.dart';
import '../core/network/document_api.dart';
import '../core/network/tenant_public_api.dart';
import '../core/network/verify_api.dart';
import '../features/document/data/datasources/document_local_data_source.dart';
import '../features/document/data/datasources/recent_file_local_data_source.dart';
import '../features/document/data/datasources/session_local_data_source.dart';
import '../features/document/data/repositories/auth_repository_impl.dart';
import '../features/document/data/repositories/document_repository_impl.dart';
import '../features/document/data/repositories/session_repository_impl.dart';
import '../features/document/data/repositories/tenant_repository_impl.dart';
import '../features/document/data/repositories/verify_repository_impl.dart';
import '../features/document/data/services/pdf_qr_tenant_detector.dart';
import '../features/document/domain/entities/stored_session.dart';
import '../features/document/domain/usecases/auth_usecases.dart';
import '../features/document/domain/usecases/document_usecases.dart';
import '../features/document/domain/usecases/session_usecases.dart';
import '../features/document/domain/usecases/tenant_usecases.dart';
import '../features/document/domain/usecases/verify_usecases.dart';

class AppDependencies {
  AppDependencies._({
    required this.initialSession,
    required this.documentUseCases,
    required this.sessionUseCases,
    required this.authUseCases,
    required this.tenantUseCases,
    required this.verifyUseCases,
  });

  final StoredSession initialSession;

  final DocumentUseCases documentUseCases;
  final SessionUseCases sessionUseCases;
  final AuthUseCases authUseCases;
  final TenantUseCases tenantUseCases;
  final VerifyUseCases verifyUseCases;

  List<RepositoryProvider> get providers => [
        RepositoryProvider.value(value: documentUseCases),
        RepositoryProvider.value(value: sessionUseCases),
        RepositoryProvider.value(value: authUseCases),
        RepositoryProvider.value(value: tenantUseCases),
        RepositoryProvider.value(value: verifyUseCases),
      ];

  static Future<AppDependencies> create() async {
    final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);

    final sessionRepository = SessionRepositoryImpl(
      localDataSource: SessionLocalDataSource(),
    );

    final documentRepository = DocumentRepositoryImpl(
      documentLocalDataSource: DocumentLocalDataSource(),
      recentFileLocalDataSource: RecentFileLocalDataSource(),
      documentApi: DocumentApi(apiClient: apiClient),
    );

    final authRepository = AuthRepositoryImpl(
      api: AuthApi(apiClient: apiClient),
    );
    final tenantRepository = TenantRepositoryImpl(
      api: TenantPublicApi(apiClient: apiClient),
    );
    final verifyRepository = VerifyRepositoryImpl(
      api: VerifyApi(apiClient: apiClient),
    );

    final documentUseCases = DocumentUseCases.fromRepository(documentRepository);
    final sessionUseCases = SessionUseCases(sessionRepository);
    final authUseCases = AuthUseCases(
      authRepository: authRepository,
      sessionRepository: sessionRepository,
    );
    final tenantUseCases = TenantUseCases(tenantRepository);
    final verifyUseCases = VerifyUseCases(
      verifyRepository: verifyRepository,
      tenantDetector: PdfQrTenantDetector(),
      sessionRepository: sessionRepository,
    );

    final initialSession = await sessionRepository.load();

    return AppDependencies._(
      initialSession: initialSession,
      documentUseCases: documentUseCases,
      sessionUseCases: sessionUseCases,
      authUseCases: authUseCases,
      tenantUseCases: tenantUseCases,
      verifyUseCases: verifyUseCases,
    );
  }
}

