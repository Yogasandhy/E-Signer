import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/auth_api.dart';
import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/field_label.dart';
import 'verify_document_screen.dart';

enum _AuthFormMode {
  login,
  register,
}

class LoginSession {
  const LoginSession({
    required this.tenantId,
    required this.userId,
    required this.userEmail,
    required this.accessToken,
  });

  final String tenantId;
  final String userId;
  final String userEmail;
  final String accessToken;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
  });

  final ValueChanged<LoginSession> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _tenantController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController =
      TextEditingController();
  _AuthFormMode _formMode = _AuthFormMode.login;
  bool _isSubmitting = false;
  bool _passwordVisible = false;
  bool _passwordConfirmationVisible = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final existingTenantId = prefs.getString(keyTenantId);
    final existingEmail = prefs.getString(keyUserEmail);
    if (existingTenantId != null && existingTenantId.trim().isNotEmpty) {
      _tenantController.text = existingTenantId;
    }
    if (existingEmail != null && existingEmail.trim().isNotEmpty) {
      _emailController.text = existingEmail;
    }
  }

  void _setFormMode(_AuthFormMode mode) {
    if (_formMode == mode) return;
    setState(() {
      _formMode = mode;
      _errorText = null;
    });
    _passwordController.clear();
    _passwordConfirmationController.clear();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    final tenantId = _tenantController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _errorText = null);
    if (tenantId.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Tenant, email, dan password wajib diisi.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authApi = context.read<AuthApi>();
      final login = await authApi.login(
        tenant: tenantId,
        email: email,
        password: password,
        deviceName: 'android',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, login.accessToken);
      await prefs.setString(keyTenantId, tenantId);
      await prefs.setString(keyUserId, login.userId);
      await prefs.setString(keyUserEmail, email);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onLoggedIn(
        LoginSession(
          tenantId: tenantId,
          userId: login.userId,
          userEmail: email,
          accessToken: login.accessToken,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _submitRegister() async {
    if (_isSubmitting) return;
    final tenantId = _tenantController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    setState(() => _errorText = null);
    if (tenantId.isEmpty ||
        name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty) {
      setState(
        () => _errorText =
            'Tenant, nama, email, password, dan konfirmasi password wajib diisi.',
      );
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = 'Password minimal 8 karakter.');
      return;
    }
    if (password != passwordConfirmation) {
      setState(() => _errorText = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authApi = context.read<AuthApi>();
      final register = await authApi.register(
        tenant: tenantId,
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        deviceName: 'android',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, register.accessToken);
      await prefs.setString(keyTenantId, tenantId);
      await prefs.setString(keyUserId, register.userId);
      await prefs.setString(keyUserEmail, email);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onLoggedIn(
        LoginSession(
          tenantId: tenantId,
          userId: register.userId,
          userEmail: email,
          accessToken: register.accessToken,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppTheme.secoundColor, width: 1.6),
    );

    final tabBorderRadius = BorderRadius.circular(12);

    return Scaffold(
      backgroundColor: AppTheme.secoundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: tabBorderRadius,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TabBar(
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerHeight: 0,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.black,
                          labelStyle: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          indicator: BoxDecoration(
                            color: AppTheme.secoundColor,
                            borderRadius: tabBorderRadius,
                          ),
                          tabs: [
                            Tab(
                              text: _formMode == _AuthFormMode.login
                                  ? 'Login'
                                  : 'Register',
                            ),
                            const Tab(text: 'Verifikasi'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Builder(
                        builder: (context) {
                          final controller = DefaultTabController.of(context);
                          return AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              return IndexedStack(
                                index: controller.index,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const FieldLabel(
                                        text: 'Tenant / Perusahaan',
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _tenantController,
                                        enabled: !_isSubmitting,
                                        cursorColor: Colors.black,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          hintText: 'contoh: demo',
                                          prefixIcon: const Icon(
                                            Icons.apartment_rounded,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: baseBorder,
                                          enabledBorder: baseBorder,
                                          focusedBorder: focusedBorder,
                                        ),
                                        onSubmitted: (_) => FocusScope.of(context)
                                            .nextFocus(),
                                      ),
                                      if (_formMode == _AuthFormMode.register) ...[
                                        const SizedBox(height: 14),
                                        const FieldLabel(text: 'Nama'),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _nameController,
                                          enabled: !_isSubmitting,
                                          cursorColor: Colors.black,
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                            hintText: 'nama lengkap',
                                            prefixIcon: const Icon(
                                              Icons.person_rounded,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            border: baseBorder,
                                            enabledBorder: baseBorder,
                                            focusedBorder: focusedBorder,
                                          ),
                                          onSubmitted: (_) =>
                                              FocusScope.of(context).nextFocus(),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      const FieldLabel(text: 'Email'),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _emailController,
                                        enabled: !_isSubmitting,
                                        cursorColor: Colors.black,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          hintText: 'contoh: test@example.com',
                                          prefixIcon: const Icon(
                                            Icons.email_rounded,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: baseBorder,
                                          enabledBorder: baseBorder,
                                          focusedBorder: focusedBorder,
                                        ),
                                        onSubmitted: (_) => FocusScope.of(context)
                                            .nextFocus(),
                                      ),
                                      const SizedBox(height: 14),
                                      const FieldLabel(text: 'Password'),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _passwordController,
                                        enabled: !_isSubmitting,
                                        cursorColor: Colors.black,
                                        obscureText: !_passwordVisible,
                                        textInputAction:
                                            _formMode == _AuthFormMode.login
                                                ? TextInputAction.done
                                                : TextInputAction.next,
                                        decoration: InputDecoration(
                                          hintText: 'contoh: secret123',
                                          prefixIcon:
                                              const Icon(Icons.lock_rounded),
                                          suffixIcon: IconButton(
                                            tooltip: _passwordVisible
                                                ? 'Hide password'
                                                : 'Show password',
                                            icon: Icon(
                                              _passwordVisible
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                            ),
                                            onPressed: _isSubmitting
                                                ? null
                                                : () => setState(
                                                      () => _passwordVisible =
                                                          !_passwordVisible,
                                                    ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: baseBorder,
                                          enabledBorder: baseBorder,
                                          focusedBorder: focusedBorder,
                                        ),
                                        onSubmitted: (_) {
                                          if (_formMode == _AuthFormMode.login) {
                                            _submitLogin();
                                          } else {
                                            FocusScope.of(context).nextFocus();
                                          }
                                        },
                                      ),
                                      if (_formMode == _AuthFormMode.register) ...[
                                        const SizedBox(height: 14),
                                        const FieldLabel(
                                          text: 'Konfirmasi Password',
                                        ),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller:
                                              _passwordConfirmationController,
                                          enabled: !_isSubmitting,
                                          cursorColor: Colors.black,
                                          obscureText:
                                              !_passwordConfirmationVisible,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            hintText: 'ulang password',
                                            prefixIcon: const Icon(
                                              Icons.lock_outline_rounded,
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip:
                                                  _passwordConfirmationVisible
                                                      ? 'Hide password'
                                                      : 'Show password',
                                              icon: Icon(
                                                _passwordConfirmationVisible
                                                    ? Icons
                                                        .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                              ),
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () => setState(
                                                        () =>
                                                            _passwordConfirmationVisible =
                                                                !_passwordConfirmationVisible,
                                                      ),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            border: baseBorder,
                                            enabledBorder: baseBorder,
                                            focusedBorder: focusedBorder,
                                          ),
                                          onSubmitted: (_) => _submitRegister(),
                                        ),
                                      ],
                                      if (_errorText != null &&
                                          _errorText!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withAlpha(16),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.red.withAlpha(40),
                                            ),
                                          ),
                                          child: Text(
                                            _errorText!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: Colors.red[700],
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.secoundColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed:
                                              _isSubmitting
                                                  ? null
                                                  : (_formMode ==
                                                          _AuthFormMode.login
                                                      ? _submitLogin
                                                      : _submitRegister),
                                          child: _isSubmitting
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  _formMode ==
                                                          _AuthFormMode.login
                                                      ? 'Masuk'
                                                      : 'Daftar',
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _formMode == _AuthFormMode.login
                                                ? 'Belum punya akun?'
                                                : 'Sudah punya akun?',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _isSubmitting
                                                ? null
                                                : () => _setFormMode(
                                                      _formMode ==
                                                              _AuthFormMode.login
                                                          ? _AuthFormMode.register
                                                          : _AuthFormMode.login,
                                                    ),
                                            child: Text(
                                              _formMode == _AuthFormMode.login
                                                  ? 'Register'
                                                  : 'Login',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  VerifyDocumentScreen(
                                    tenantController: _tenantController,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
