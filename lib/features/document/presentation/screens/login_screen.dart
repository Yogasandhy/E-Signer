import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/auth_api.dart';
import '../../../../presentation/app_theme.dart';
import 'verify_document_screen.dart';
import 'login_form.dart';
import 'register_form.dart';

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
  final TextEditingController _tenantNameController = TextEditingController();
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
    final tenantSlug = _tenantController.text.trim();
    final tenantName = _tenantNameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    setState(() => _errorText = null);
    if (tenantName.isEmpty ||
        name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty) {
      setState(
        () => _errorText =
            'Nama perusahaan, nama, email, password, dan konfirmasi password wajib diisi.',
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
        tenantName: tenantName,
        tenantSlug: tenantSlug.isEmpty ? null : tenantSlug,
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      final resolvedTenantSlug =
          (register.tenantSlug ?? '').trim().isNotEmpty ? register.tenantSlug!.trim() : tenantSlug;
      if (resolvedTenantSlug.trim().isEmpty) {
        throw Exception('Register response missing tenantSlug.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, register.accessToken);
      await prefs.setString(keyTenantId, resolvedTenantSlug);
      await prefs.setString(keyUserId, register.userId);
      await prefs.setString(keyUserEmail, email);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _tenantController.text = resolvedTenantSlug;
      widget.onLoggedIn(
        LoginSession(
          tenantId: resolvedTenantSlug,
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
    _tenantNameController.dispose();
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
                  initialIndex: 1,
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
                                  _formMode == _AuthFormMode.login
                                      ? LoginForm(
                                          tenantController: _tenantController,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          isSubmitting: _isSubmitting,
                                          passwordVisible: _passwordVisible,
                                          onTogglePasswordVisible: () =>
                                              setState(
                                            () => _passwordVisible =
                                                !_passwordVisible,
                                          ),
                                          onSubmit: _submitLogin,
                                          onSwitchToRegister: () =>
                                              _setFormMode(
                                            _AuthFormMode.register,
                                          ),
                                          baseBorder: baseBorder,
                                          focusedBorder: focusedBorder,
                                          errorText: _errorText,
                                        )
                                      : RegisterForm(
                                          tenantSlugController:
                                              _tenantController,
                                          tenantNameController:
                                              _tenantNameController,
                                          nameController: _nameController,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          passwordConfirmationController:
                                              _passwordConfirmationController,
                                          isSubmitting: _isSubmitting,
                                          passwordVisible: _passwordVisible,
                                          passwordConfirmationVisible:
                                              _passwordConfirmationVisible,
                                          onTogglePasswordVisible: () =>
                                              setState(
                                            () => _passwordVisible =
                                                !_passwordVisible,
                                          ),
                                          onTogglePasswordConfirmationVisible:
                                              () => setState(
                                            () =>
                                                _passwordConfirmationVisible =
                                                    !_passwordConfirmationVisible,
                                          ),
                                          onSubmit: _submitRegister,
                                          onSwitchToLogin: () => _setFormMode(
                                            _AuthFormMode.login,
                                          ),
                                          baseBorder: baseBorder,
                                          focusedBorder: focusedBorder,
                                          errorText: _errorText,
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
