import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/storage_keys.dart';
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

  final documentRepository = DocumentRepositoryImpl(
    documentLocalDataSource: DocumentLocalDataSource(),
    recentFileLocalDataSource: RecentFileLocalDataSource(),
  );

  final documentUseCases = DocumentUseCases.fromRepository(documentRepository);
  final prefs = await SharedPreferences.getInstance();
  final initialTenantId = prefs.getString(keyTenantId);
  final initialUserId = prefs.getString(keyUserId);

  runApp(
    RepositoryProvider.value(
      value: documentUseCases,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        home: _AppRoot(
          initialTenantId: initialTenantId,
          initialUserId: initialUserId,
        ),
      ),
    ),
  );
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.initialTenantId,
    required this.initialUserId,
  });

  final String? initialTenantId;
  final String? initialUserId;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late String? _tenantId;
  late String? _userId;

  @override
  void initState() {
    super.initState();
    _tenantId = widget.initialTenantId?.trim().isEmpty ?? true
        ? null
        : widget.initialTenantId!.trim();
    _userId = widget.initialUserId?.trim().isEmpty ?? true
        ? null
        : widget.initialUserId!.trim();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyTenantId);
    await prefs.remove(keyUserId);
    if (!mounted) return;
    setState(() {
      _tenantId = null;
      _userId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = _tenantId;
    final userId = _userId;
    if (tenantId == null || userId == null) {
      return LoginScreen(
        onLoggedIn: (session) {
          setState(() {
            _tenantId = session.tenantId.trim();
            _userId = session.userId.trim();
          });
        },
      );
    }

    final documentUseCases = context.read<DocumentUseCases>();
    return BlocProvider(
      create: (_) => RecentDocumentsBloc(
        documentUseCases: documentUseCases,
        tenantId: tenantId,
        userId: userId,
      )..add(const RecentDocumentsLoaded()),
      child: HomeScreen(
        tenantId: tenantId,
        userId: userId,
        onLogout: _logout,
      ),
    );
  }
}
