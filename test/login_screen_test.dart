import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttd/core/errors/api_exception.dart';
import 'package:ttd/features/document/domain/entities/auth_session.dart';
import 'package:ttd/features/document/domain/entities/stored_session.dart';
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

class _ThrowingAuthRepository implements AuthRepository {
  // Repo palsu untuk mensimulasikan login gagal (misalnya HTTP 401).
  _ThrowingAuthRepository(this.error);

  final Exception error;

  @override
  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) async {
    throw error;
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

class _DelayedAuthRepository implements AuthRepository {
  // Repo palsu untuk mensimulasikan login sukses tapi ada delay (agar bisa ngetes
  // loading indicator di tombol).
  _DelayedAuthRepository({
    required this.delay,
    required this.session,
  });

  final Duration delay;
  final AuthSession session;

  @override
  Future<AuthSession> login({
    required String tenant,
    required String email,
    required String password,
    String deviceName = 'android',
  }) {
    return Future<AuthSession>.delayed(delay, () => session);
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
      // 0 = tenant, 1 = email, 2 = password
      await tester.enterText(find.byType(TextField).at(0), 'demo');
      await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(2), '1234567');
      await tester.pump();

      expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(loginButtonFinder).onPressed,
        isNull,
      );

      // Setelah password valid (>= 8), tombol harus enable.
      await tester.enterText(find.byType(TextField).at(2), '12345678');
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
          authRepository: _ThrowingAuthRepository(
            const ApiException('Unauthorized', statusCode: 401),
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'demo');
      await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(2), '12345678');
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
          authRepository: _DelayedAuthRepository(
            delay: const Duration(milliseconds: 200),
            session: const AuthSession(
              accessToken: 'token-123',
              tenant: 'demo',
              userId: 'user-1',
            ),
          ),
          sessionRepository: _MemorySessionRepository(),
        ),
        onLoggedIn: completer.complete,
      );

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'demo');
      await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(2), '12345678');
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
  });
}
