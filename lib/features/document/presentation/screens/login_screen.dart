import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../presentation/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
  });

  final ValueChanged<String> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(keyUserId);
    if (existing == null || existing.trim().isEmpty) return;
    _controller.text = existing;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final userId = _controller.text.trim();
    if (userId.isEmpty) return;

    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserId, userId);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    widget.onLoggedIn(userId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.secoundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                    'Masukkan User ID / Email (sementara).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      hintText: 'contoh: user@email.com',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secoundColor,
                        foregroundColor: Colors.white,
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
    );
  }
}

