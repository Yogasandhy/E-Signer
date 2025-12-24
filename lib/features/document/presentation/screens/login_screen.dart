import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_exception.dart';
import '../../domain/entities/tenant_membership.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../../presentation/app_theme.dart';
import 'verify_document_screen.dart';
import 'login_form.dart';
import 'register_form.dart';
import '../widgets/tenant_picker_dialog.dart';

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
  static final RegExp _emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _tenantSlugRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$');

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
  bool _loginAttempted = false;
  bool _registerAttempted = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tenantController.addListener(_handleFormChanged);
    _tenantNameController.addListener(_handleFormChanged);
    _nameController.addListener(_handleFormChanged);
    _emailController.addListener(_handleFormChanged);
    _passwordController.addListener(_handleFormChanged);
    _passwordConfirmationController.addListener(_handleFormChanged);
  }

  void _handleFormChanged() {
    if (!mounted) return;
    setState(() => _errorText = null);
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    return value.isNotEmpty && _emailRegex.hasMatch(value);
  }

  bool _isValidTenantSlug(String slug) {
    final value = slug.trim();
    return value.isNotEmpty && _tenantSlugRegex.hasMatch(value);
  }

  bool _isAllowedUserRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return normalized == 'user';
  }

  bool get _canSubmitLogin {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) return false;
    if (!_isValidEmail(email)) return false;
    if (password.length < 8) return false;
    return true;
  }

  bool get _canSubmitRegister {
    final tenantSlug = _tenantController.text.trim();
    final tenantName = _tenantNameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    if (tenantSlug.isNotEmpty && !_isValidTenantSlug(tenantSlug)) return false;
    if (tenantName.isEmpty ||
        name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty) {
      return false;
    }
    if (!_isValidEmail(email)) return false;
    if (password.length < 8) return false;
    if (password != passwordConfirmation) return false;
    return true;
  }

  String? get _loginEmailErrorText {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return _loginAttempted ? 'Email wajib diisi.' : null;
    }
    if (!_isValidEmail(email)) {
      return 'Email tidak valid.';
    }
    return null;
  }

  String? get _loginPasswordErrorText {
    final password = _passwordController.text;
    if (password.isEmpty) {
      return _loginAttempted ? 'Password wajib diisi.' : null;
    }
    if (password.length < 8) {
      return 'Password minimal 8 karakter.';
    }
    return null;
  }

  String? get _registerTenantSlugErrorText {
    final slug = _tenantController.text.trim();
    if (slug.isEmpty) return null;
    if (!_tenantSlugRegex.hasMatch(slug)) {
      return 'Slug hanya boleh huruf/angka, "-" atau "_".';
    }
    return null;
  }

  String? get _registerTenantNameErrorText {
    final tenantName = _tenantNameController.text.trim();
    if (tenantName.isEmpty) {
      return _registerAttempted ? 'Nama perusahaan wajib diisi.' : null;
    }
    return null;
  }

  String? get _registerNameErrorText {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return _registerAttempted ? 'Nama wajib diisi.' : null;
    }
    return null;
  }

  String? get _registerEmailErrorText {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return _registerAttempted ? 'Email wajib diisi.' : null;
    }
    if (!_isValidEmail(email)) {
      return 'Email tidak valid.';
    }
    return null;
  }

  String? get _registerPasswordErrorText {
    final password = _passwordController.text;
    if (password.isEmpty) {
      return _registerAttempted ? 'Password wajib diisi.' : null;
    }
    if (password.length < 8) {
      return 'Password minimal 8 karakter.';
    }
    return null;
  }

  String? get _registerPasswordConfirmationErrorText {
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    if (passwordConfirmation.isEmpty) {
      return _registerAttempted ? 'Konfirmasi password wajib diisi.' : null;
    }
    if (passwordConfirmation != password) {
      return 'Konfirmasi password tidak sama.';
    }
    return null;
  }

  String _formatAuthError(Object error, {required bool isLogin}) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (isLogin) {
        if (error.statusCode == 401 ||
            message.toLowerCase().contains('unauthorized')) {
          return 'Email atau password salah.';
        }
        if (error.statusCode == 404) {
          return 'Tenant tidak ditemukan.';
        }
      }
      return message.isEmpty ? 'Terjadi kesalahan.' : message;
    }

    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message.isEmpty ? 'Terjadi kesalahan.' : message;
  }

  void _setFormMode(_AuthFormMode mode) {
    if (_formMode == mode) return;
    setState(() {
      _formMode = mode;
      _errorText = null;
      _loginAttempted = false;
      _registerAttempted = false;
    });
    _passwordController.clear();
    _passwordConfirmationController.clear();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    setState(() {
      _loginAttempted = true;
      _errorText = null;
    });
    if (!_canSubmitLogin) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);
    try {
      final authUseCases = context.read<AuthUseCases>();
      final centralLogin = await authUseCases.loginCentral(
        email: email,
        password: password,
      );

      if (!mounted) return;
      if (centralLogin.tenants.isEmpty) {
        setState(() {
          _isSubmitting = false;
          _errorText =
              'Akun kamu belum terdaftar di tenant manapun. Silakan hubungi admin.';
        });
        return;
      }

      final userTenants = centralLogin.tenants
          .where((t) => _isAllowedUserRole(t.role))
          .toList(growable: false);
      if (userTenants.isEmpty) {
        setState(() {
          _isSubmitting = false;
          _errorText =
              'Akun ini tidak memiliki akses sebagai user. Gunakan akun role user atau aplikasi admin.';
        });
        return;
      }

      TenantMembership? selectedTenant;
      if (userTenants.length == 1) {
        selectedTenant = userTenants.first;
      } else {
        setState(() => _isSubmitting = false);
        selectedTenant = await showTenantPickerDialog(
          context: context,
          tenants: userTenants,
        );
        if (!mounted || selectedTenant == null) return;
        setState(() => _isSubmitting = true);
      }

      final tenantSession = await authUseCases.selectTenant(
        centralAccessToken: centralLogin.accessToken,
        tenant: selectedTenant.slug,
        userId: centralLogin.userId,
        userEmail: (centralLogin.userEmail ?? email).trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onLoggedIn(
        LoginSession(
          tenantId: tenantSession.tenant,
          userId: tenantSession.userId,
          userEmail: (centralLogin.userEmail ?? email).trim(),
          accessToken: tenantSession.accessToken,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _formatAuthError(e, isLogin: true);
      });
    }
  }

  Future<void> _submitRegister() async {
    if (_isSubmitting) return;
    setState(() {
      _registerAttempted = true;
      _errorText = null;
    });
    if (!_canSubmitRegister) {
      return;
    }

    final tenantSlug = _tenantController.text.trim();
    final tenantName = _tenantNameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    setState(() => _isSubmitting = true);
    try {
      final authUseCases = context.read<AuthUseCases>();
      final register = await authUseCases.registerTenant(
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
        _errorText = _formatAuthError(e, isLogin: false);
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
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          isSubmitting: _isSubmitting,
                                          canSubmit: _canSubmitLogin,
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
                                          emailErrorText: _loginEmailErrorText,
                                          passwordErrorText:
                                              _loginPasswordErrorText,
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
                                          canSubmit: _canSubmitRegister,
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
                                          tenantSlugErrorText:
                                              _registerTenantSlugErrorText,
                                          tenantNameErrorText:
                                              _registerTenantNameErrorText,
                                          nameErrorText: _registerNameErrorText,
                                          emailErrorText: _registerEmailErrorText,
                                          passwordErrorText:
                                              _registerPasswordErrorText,
                                          passwordConfirmationErrorText:
                                              _registerPasswordConfirmationErrorText,
                                        ),
                                  VerifyDocumentScreen(
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
