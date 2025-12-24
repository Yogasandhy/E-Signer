import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttd/core/errors/api_exception.dart';
import 'package:ttd/features/document/domain/entities/auth_session.dart';
import 'package:ttd/features/document/domain/entities/central_login_result.dart';
import 'package:ttd/features/document/domain/entities/select_tenant_result.dart';
import 'package:ttd/features/document/domain/entities/stored_session.dart';
import 'package:ttd/features/document/domain/entities/tenant_membership.dart';
import 'package:ttd/features/document/domain/repositories/auth_repository.dart';
import 'package:ttd/features/document/domain/repositories/session_repository.dart';
import 'package:ttd/features/document/domain/usecases/auth_usecases.dart';
import 'package:ttd/features/document/presentation/screens/login_screen.dart';
import 'package:ttd/presentation/app_theme.dart';

// File ini berisi widget test untuk `LoginScreen`.
//
// Kenapa widget test?
// - Karena kita mau memastikan UI/UX (enable/disable tombol, error text, loading)
//   berjalan benar ketika user mengetik input / submit.

class _NoopAuthRepository implements AuthRepository {
  // Stub repo: sengaja tidak dipakai untuk request jaringan.
  // Digunakan untuk test "validasi UI" saja (tombol enable/disable, error per field).
  @override
  Future<CentralLoginResult> loginCentral({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SelectTenantResult> selectTenant({
    required String centralAccessToken,
    required String tenant,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> registerTenant({
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> me({
    required String tenant,
    required String accessToken,
  }) {
    throw UnimplementedError();
  }
}

typedef _LoginCentralHandler = Future<CentralLoginResult> Function(
  String email,
  String password,
);
typedef _SelectTenantHandler = Future<SelectTenantResult> Function(
  String centralAccessToken,
  String tenant,
);

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({
    required this.loginCentralHandler,
    required this.selectTenantHandler,
  });

  final _LoginCentralHandler loginCentralHandler;
  final _SelectTenantHandler selectTenantHandler;

  @override
  Future<CentralLoginResult> loginCentral({
    required String email,
    required String password,
  }) {
    return loginCentralHandler(email, password);
  }

  @override
  Future<SelectTenantResult> selectTenant({
    required String centralAccessToken,
    required String tenant,
  }) {
    return selectTenantHandler(centralAccessToken, tenant);
  }

  @override
  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> registerTenant({
    required String tenantName,
    String? tenantSlug,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? role,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> me({
    required String tenant,
    required String accessToken,
  }) {
    throw UnimplementedError();
  }
}

class _MemorySessionRepository implements SessionRepository {
  // Session repository in-memory: menyimpan session di variabel agar `AuthUseCases`
  // bisa memanggil `save()` tanpa perlu SharedPreferences/file.
  StoredSession _session = const StoredSession();
  String? _lastTenant;

  @override
  Future<StoredSession> load() async => _session;

  @override
  Future<void> save({
    required String accessToken,
    required String tenant,
    required String userId,
    required String userEmail,
  }) async {
    _session = StoredSession(
      accessToken: accessToken,
      tenant: tenant,
      userId: userId,
      userEmail: userEmail,
    );
  }

  @override
  Future<void> clear({bool keepTenant = true}) async {
    final tenant = keepTenant ? _session.tenant : null;
    _session = StoredSession(tenant: tenant);
    if (!keepTenant) _lastTenant = null;
  }

  @override
  Future<String?> getLastTenant() async => _lastTenant;

  @override
  Future<void> setLastTenant(String tenant) async {
    _lastTenant = tenant;
  }
}

Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  required AuthUseCases authUseCases,
  ValueChanged<LoginSession>? onLoggedIn,
}) {
  // Membungkus `LoginScreen` dengan:
  // - `RepositoryProvider<AuthUseCases>` agar `LoginScreen` bisa `context.read<AuthUseCases>()`
  // - `MaterialApp` supaya widget Material (TabBar, ElevatedButton, dll) bisa dirender.
  return tester.pumpWidget(
    RepositoryProvider<AuthUseCases>.value(
      value: authUseCases,
      child: MaterialApp(
        theme: AppTheme.themeData,
        home: LoginScreen(
          onLoggedIn: onLoggedIn ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('LoginScreen validation', () {
    testWidgets('login button disabled until inputs valid', (tester) async {
      // Test ini fokus ke validasi Login:
      // - Tombol "Masuk" harus disable kalau input belum valid.
      // - Password minimal 8 karakter.
      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _NoopAuthRepository(),
          sessionRepository: _MemorySessionRepository(),
        ),
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Cari tombol submit login. `onPressed == null` artinya disabled.
      final loginButtonFinder =
          find.widgetWithText(ElevatedButton, 'Masuk');

      expect(
        tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
        isNull,
      );

      // Urutan TextField pada form login:
      // 0 = email, 1 = password
      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '1234567');
      await tester.pump();

      expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
        isNull,
      );

      // Setelah password valid (>= 8), tombol harus enable.
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.pump();

      expect(find.text('Password minimal 8 karakter.'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
        isNotNull,
      );
    });

    testWidgets('register button disabled until inputs valid', (tester) async {
      // Test ini fokus ke validasi Register:
      // - Tombol "Daftar" disabled sampai semua field valid.
      // - Konfirmasi password harus sama.
      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _NoopAuthRepository(),
          sessionRepository: _MemorySessionRepository(),
        ),
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      // Tombol submit register.
      final registerButtonFinder =
          find.widgetWithText(ElevatedButton, 'Daftar');

      expect(
        tester.widget<ElevatedButton>(registerButtonFinder).onPressed,
        isNull,
      );

      // Urutan TextField pada form register:
      // 0 = slug (opsional), 1 = nama perusahaan, 2 = nama, 3 = email,
      // 4 = password, 5 = konfirmasi password
      await tester.enterText(find.byType(TextField).at(1), 'PT Demo');
      await tester.enterText(find.byType(TextField).at(2), 'Rifqi');
      await tester.enterText(
        find.byType(TextField).at(3),
        'rifqi@example.com',
      );
      await tester.enterText(find.byType(TextField).at(4), '12345678');
      await tester.enterText(find.byType(TextField).at(5), '1234567');
      await tester.pump();

      // Password mismatch → tampil error dan tombol tetap disabled.
      expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(registerButtonFinder).onPressed,
        isNull,
      );

      // Password match → error hilang dan tombol jadi enabled.
      await tester.enterText(find.byType(TextField).at(5), '12345678');
      await tester.pump();

      expect(find.text('Konfirmasi password tidak sama.'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(registerButtonFinder).onPressed,
        isNotNull,
      );
    });
  });

  group('LoginScreen submit', () {
    testWidgets('shows friendly error on unauthorized login', (tester) async {
      // Test ini memastikan mapping error login:
      // ApiException(401) harus ditampilkan jadi pesan ramah:
      // "Email atau password salah."
      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _FakeAuthRepository(
            loginCentralHandler: (_, _) => Future<CentralLoginResult>.error(
              const ApiException('Unauthorized', statusCode: 401),
            ),
            selectTenantHandler: (_, _) =>
                Future<SelectTenantResult>.error(UnimplementedError()),
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email atau password salah.'), findsOneWidget);
    });

    testWidgets('shows loading state and calls onLoggedIn', (tester) async {
      // Test ini memastikan flow sukses:
      // - Tombol berubah jadi loading indicator saat request berjalan
      // - Callback `onLoggedIn` dipanggil saat login sukses
      final completer = Completer<LoginSession>();

      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _FakeAuthRepository(
            loginCentralHandler: (email, password) {
              return Future<CentralLoginResult>.delayed(
                const Duration(milliseconds: 200),
                () => CentralLoginResult(
                  accessToken: 'central-123',
                  userId: 'user-1',
                  userEmail: email,
                  tenants: const [
                    TenantMembership(
                      id: 'tenant-1',
                      name: 'PT Demo Company',
                      slug: 'demo',
                      role: 'user',
                      isOwner: false,
                    ),
                  ],
                ),
              );
            },
            selectTenantHandler: (_, tenant) {
              return Future<SelectTenantResult>.value(
                SelectTenantResult(
                  accessToken: 'token-123',
                  tenant: TenantMembership(
                    id: 'tenant-1',
                    name: 'PT Demo Company',
                    slug: tenant,
                    role: 'user',
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
        onLoggedIn: completer.complete,
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pump();

      // Setelah tap submit, tombol menampilkan progress.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Menunggu future login selesai (delay 200ms).
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(completer.isCompleted, isTrue);
      final session = await completer.future;
      expect(session.tenantId, 'demo');
      expect(session.accessToken, 'token-123');

      // Loading hilang dan tombol kembali ke teks.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('blocks login for non-user roles', (tester) async {
      var loggedInCalls = 0;

      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _FakeAuthRepository(
            loginCentralHandler: (email, password) {
              return Future<CentralLoginResult>.value(
                CentralLoginResult(
                  accessToken: 'central-1',
                  userId: 'admin-1',
                  userEmail: email,
                  tenants: const [
                    TenantMembership(
                      id: 'tenant-1',
                      name: 'PT Demo Company',
                      slug: 'demo',
                      role: 'super_admin',
                      isOwner: true,
                    ),
                  ],
                ),
              );
            },
            selectTenantHandler: (_, _) =>
                Future<SelectTenantResult>.error(UnimplementedError()),
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
        onLoggedIn: (_) => loggedInCalls++,
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'admin@example.com');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(loggedInCalls, 0);
      expect(
        find.textContaining('tidak memiliki akses sebagai user'),
        findsOneWidget,
      );
    });

    testWidgets('prompts tenant selection when multiple user tenants', (tester) async {
      final completer = Completer<LoginSession>();

      const tenants = [
        TenantMembership(
          id: 'tenant-1',
          name: 'PT Demo Company',
          slug: 'demo',
          role: 'user',
          isOwner: false,
        ),
        TenantMembership(
          id: 'tenant-2',
          name: 'PT Another Company',
          slug: 'another',
          role: 'super_admin',
          isOwner: true,
        ),
        TenantMembership(
          id: 'tenant-3',
          name: 'PT Branch Company',
          slug: 'branch',
          role: 'user',
          isOwner: false,
        ),
      ];

      await _pumpLoginScreen(
        tester,
        authUseCases: AuthUseCases(
          authRepository: _FakeAuthRepository(
            loginCentralHandler: (email, password) {
              return Future<CentralLoginResult>.value(
                CentralLoginResult(
                  accessToken: 'central-1',
                  userId: 'user-1',
                  userEmail: email,
                  tenants: tenants,
                ),
              );
            },
            selectTenantHandler: (_, tenant) async {
              final selected = tenants.firstWhere((t) => t.slug == tenant);
              return SelectTenantResult(
                accessToken: 'tenant-token-$tenant',
                tenant: selected,
              );
            },
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
        onLoggedIn: completer.complete,
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Tenant'), findsOneWidget);
      expect(find.text('PT Demo Company'), findsOneWidget);
      expect(find.text('PT Another Company'), findsNothing);
      expect(find.text('PT Branch Company'), findsOneWidget);

      await tester.tap(find.text('PT Branch Company'));
      await tester.pumpAndSettle();

      expect(completer.isCompleted, isTrue);
      final session = await completer.future;
      expect(session.tenantId, 'branch');
      expect(session.accessToken, 'tenant-token-branch');
    });
  });
}
