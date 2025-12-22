import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/document/domain/entities/stored_session.dart';
import '../features/document/domain/usecases/auth_usecases.dart';
import '../features/document/domain/usecases/document_usecases.dart';
import '../features/document/domain/usecases/session_usecases.dart';
import '../features/document/presentation/bloc/recent_documents/recent_documents_bloc.dart';
import '../features/document/presentation/bloc/recent_documents/recent_documents_event.dart';
import '../features/document/presentation/screens/home_screen.dart';
import '../features/document/presentation/screens/login_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.initialSession,
  });

  final StoredSession initialSession;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late String? _accessToken;
  late String? _tenantId;
  late String? _userId;
  late String? _userEmail;
  Future<bool>? _meCheck;

  @override
  void initState() {
    super.initState();
    _accessToken = widget.initialSession.accessToken;
    _tenantId = widget.initialSession.tenant;
    _userId = widget.initialSession.userId;
    _userEmail = widget.initialSession.userEmail;
  }

  Future<void> _logout() async {
    await context.read<SessionUseCases>().clear(keepTenant: true);
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
    required AuthUseCases authUseCases,
    required String tenantId,
    required String accessToken,
  }) {
    return authUseCases
        .me(tenant: tenantId, accessToken: accessToken)
        .then((_) => true)
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authUseCases = context.read<AuthUseCases>();

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
            _userEmail = session.userEmail.trim().isEmpty
                ? null
                : session.userEmail.trim();
            _meCheck = _ensureMeCheck(
              authUseCases: authUseCases,
              tenantId: session.tenantId.trim(),
              accessToken: session.accessToken.trim(),
            );
          });
        },
      );
    }

    final documentUseCases = context.read<DocumentUseCases>();

    _meCheck ??= _ensureMeCheck(
      authUseCases: authUseCases,
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

