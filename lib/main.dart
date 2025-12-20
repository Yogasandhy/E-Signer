import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/api_config.dart';
import 'core/constants/storage_keys.dart';
import 'core/network/api_client.dart';
import 'core/network/auth_api.dart';
import 'core/network/document_api.dart';
import 'core/network/verify_api.dart';
import 'features/document/data/datasources/document_local_data_source.dart';
import 'features/document/data/datasources/recent_file_local_data_source.dart';
import 'features/document/data/repositories/document_repository_impl.dart';
import 'features/document/domain/usecases/document_usecases.dart';
import 'features/document/presentation/bloc/recent_documents/recent_documents_bloc.dart';
import 'features/document/presentation/bloc/recent_documents/recent_documents_event.dart';
import 'features/document/presentation/screens/home_screen.dart';
import 'features/document/presentation/screens/login_screen.dart';
import 'presentation/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);
  final documentApi = DocumentApi(apiClient: apiClient);
  final documentRepository = DocumentRepositoryImpl(
    documentLocalDataSource: DocumentLocalDataSource(),
    recentFileLocalDataSource: RecentFileLocalDataSource(),
    documentApi: documentApi,
  );

  final authApi = AuthApi(apiClient: apiClient);
  final verifyApi = VerifyApi(apiClient: apiClient);
  final documentUseCases = DocumentUseCases.fromRepository(documentRepository);
  final prefs = await SharedPreferences.getInstance();
  final initialAccessToken = prefs.getString(keyAccessToken);
  final initialTenantId = prefs.getString(keyTenantId);
  final initialUserId = prefs.getString(keyUserId);
  final initialUserEmail = prefs.getString(keyUserEmail);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authApi),
        RepositoryProvider.value(value: verifyApi),
        RepositoryProvider.value(value: documentUseCases),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: _AppRoot(
          initialAccessToken: initialAccessToken,
          initialTenantId: initialTenantId,
          initialUserId: initialUserId,
          initialUserEmail: initialUserEmail,
        ),
      ),
    ),
  );
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.initialAccessToken,
    required this.initialTenantId,
    required this.initialUserId,
    required this.initialUserEmail,
  });

  final String? initialAccessToken;
  final String? initialTenantId;
  final String? initialUserId;
  final String? initialUserEmail;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late String? _accessToken;
  late String? _tenantId;
  late String? _userId;
  late String? _userEmail;
  Future<bool>? _meCheck;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.initialAccessToken?.trim().isEmpty ?? true
        ? null
        : widget.initialAccessToken!.trim();
    _tenantId = widget.initialTenantId?.trim().isEmpty ?? true
        ? null
        : widget.initialTenantId!.trim();
    _userId = widget.initialUserId?.trim().isEmpty ?? true
        ? null
        : widget.initialUserId!.trim();
    _userEmail = widget.initialUserEmail?.trim().isEmpty ?? true
        ? null
        : widget.initialUserEmail!.trim();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyTenantId);
    await prefs.remove(keyUserId);
    await prefs.remove(keyUserEmail);
    if (!mounted) return;
    setState(() {
      _accessToken = null;
      _tenantId = null;
      _userId = null;
      _userEmail = null;
      _meCheck = null;
    });
  }

  Future<bool> _ensureMeCheck({
    required AuthApi authApi,
    required String tenantId,
    required String accessToken,
  }) {
    return authApi
        .me(tenant: tenantId, accessToken: accessToken)
        .then((_) => true)
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authApi = context.read<AuthApi>();
    final accessToken = _accessToken;
    final tenantId = _tenantId;
    final userId = _userId;
    final userEmail = _userEmail;
    if (accessToken == null || tenantId == null || userId == null) {
      return LoginScreen(
        onLoggedIn: (session) {
          setState(() {
            _accessToken = session.accessToken.trim();
            _tenantId = session.tenantId.trim();
            _userId = session.userId.trim();
            _userEmail = session.userEmail.trim().isEmpty ? null : session.userEmail.trim();
            _meCheck = _ensureMeCheck(
              authApi: authApi,
              tenantId: session.tenantId.trim(),
              accessToken: session.accessToken.trim(),
            );
          });
        },
      );
    }

    final documentUseCases = context.read<DocumentUseCases>();

    _meCheck ??= _ensureMeCheck(
      authApi: authApi,
      tenantId: tenantId,
      accessToken: accessToken,
    );

    return FutureBuilder<bool>(
      future: _meCheck,
      builder: (context, snapshot) {
        final ok = snapshot.data == true;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (!ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _logout());
          return const Scaffold(
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return BlocProvider(
          create: (_) => RecentDocumentsBloc(
            documentUseCases: documentUseCases,
            tenantId: tenantId,
            userId: userId,
          )..add(const RecentDocumentsLoaded()),
          child: HomeScreen(
            tenantId: tenantId,
            userId: userId,
            accessToken: accessToken,
            userEmail: userEmail,
            onLogout: _logout,
          ),
        );
      },
    );
  }
}
