import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../presentation/app_theme.dart';

class LoginSession {
  const LoginSession({
    required this.tenantId,
    required this.userId,
  });

  final String tenantId;
  final String userId;
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
  final TextEditingController _userController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final existingTenantId = prefs.getString(keyTenantId);
    final existing = prefs.getString(keyUserId);
    if (existingTenantId != null && existingTenantId.trim().isNotEmpty) {
      _tenantController.text = existingTenantId;
    }
    if (existing != null && existing.trim().isNotEmpty) {
      _userController.text = existing;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final tenantId = _tenantController.text.trim();
    final userId = _userController.text.trim();
    if (tenantId.isEmpty || userId.isEmpty) return;

    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTenantId, tenantId);
    await prefs.setString(keyUserId, userId);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    widget.onLoggedIn(LoginSession(tenantId: tenantId, userId: userId));
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _userController.dispose();
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

    return Scaffold(
      backgroundColor: AppTheme.secoundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secoundColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan tenant (perusahaan) dan User ID / Email.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel(text: 'Tenant / Perusahaan'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _tenantController,
                      enabled: !_isSubmitting,
                      cursorColor: Colors.black,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'contoh: acme',
                        prefixIcon: const Icon(Icons.apartment_rounded),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: baseBorder,
                        enabledBorder: baseBorder,
                        focusedBorder: focusedBorder,
                      ),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(text: 'User ID'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _userController,
                      enabled: !_isSubmitting,
                      cursorColor: Colors.black,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'contoh: user@email.com',
                        prefixIcon: const Icon(Icons.person_rounded),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: baseBorder,
                        enabledBorder: baseBorder,
                        focusedBorder: focusedBorder,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secoundColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: Colors.grey[800],
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
