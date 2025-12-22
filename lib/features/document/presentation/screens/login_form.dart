import 'package:flutter/material.dart';

import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/field_label.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.tenantController,
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.passwordVisible,
    required this.onTogglePasswordVisible,
    required this.onSubmit,
    required this.onSwitchToRegister,
    required this.baseBorder,
    required this.focusedBorder,
    this.errorText,
  });

  final TextEditingController tenantController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final bool passwordVisible;
  final VoidCallback onTogglePasswordVisible;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchToRegister;
  final String? errorText;
  final OutlineInputBorder baseBorder;
  final OutlineInputBorder focusedBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel(text: 'Tenant / Perusahaan'),
        const SizedBox(height: 6),
        TextField(
          controller: tenantController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'contoh: demo',
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
        const FieldLabel(text: 'Email'),
        const SizedBox(height: 6),
        TextField(
          controller: emailController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'contoh: test@example.com',
            prefixIcon: const Icon(Icons.email_rounded),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
          ),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 14),
        const FieldLabel(text: 'Password'),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          obscureText: !passwordVisible,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'contoh: secret123',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              tooltip: passwordVisible ? 'Hide password' : 'Show password',
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: isSubmitting ? null : onTogglePasswordVisible,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorText != null && errorText!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(40)),
            ),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
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
              backgroundColor: AppTheme.secoundColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isSubmitting ? null : onSubmit,
            child: isSubmitting
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Belum punya akun?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: isSubmitting ? null : onSwitchToRegister,
              child: const Text(
                'Register',
                style: TextStyle(
                  fontWeight: FontWeight.w800,color: Colors.blue
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

