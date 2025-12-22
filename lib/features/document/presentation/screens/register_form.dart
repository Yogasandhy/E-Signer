import 'package:flutter/material.dart';

import '../../../../presentation/app_theme.dart';
import '../../../../presentation/components/field_label.dart';

class RegisterForm extends StatelessWidget {
  const RegisterForm({
    super.key,
    required this.tenantSlugController,
    required this.tenantNameController,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.isSubmitting,
    required this.passwordVisible,
    required this.passwordConfirmationVisible,
    required this.onTogglePasswordVisible,
    required this.onTogglePasswordConfirmationVisible,
    required this.onSubmit,
    required this.onSwitchToLogin,
    required this.baseBorder,
    required this.focusedBorder,
    this.errorText,
  });

  final TextEditingController tenantSlugController;
  final TextEditingController tenantNameController;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmationController;
  final bool isSubmitting;
  final bool passwordVisible;
  final bool passwordConfirmationVisible;
  final VoidCallback onTogglePasswordVisible;
  final VoidCallback onTogglePasswordConfirmationVisible;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchToLogin;
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
        const FieldLabel(text: 'Slug Perusahaan (Opsional)'),
        const SizedBox(height: 6),
        TextField(
          controller: tenantSlugController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'demo (opsional)',
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
        const FieldLabel(text: 'Nama Perusahaan'),
        const SizedBox(height: 6),
        TextField(
          controller: tenantNameController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Nama perusahaan',
            prefixIcon: const Icon(Icons.business_rounded),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
          ),
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 14),
        const FieldLabel(text: 'Nama'),
        const SizedBox(height: 6),
        TextField(
          controller: nameController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'nama lengkap',
            prefixIcon: const Icon(Icons.person_rounded),
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
            hintText: 'email@domain.com',
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
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'minimal 8 karakter',
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
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 14),
        const FieldLabel(text: 'Konfirmasi Password'),
        const SizedBox(height: 6),
        TextField(
          controller: passwordConfirmationController,
          enabled: !isSubmitting,
          cursorColor: Colors.black,
          obscureText: !passwordConfirmationVisible,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'ulang password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip:
                  passwordConfirmationVisible ? 'Hide password' : 'Show password',
              icon: Icon(
                passwordConfirmationVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: isSubmitting ? null : onTogglePasswordConfirmationVisible,
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
                : const Text('Daftar'),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sudah punya akun?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: isSubmitting ? null : onSwitchToLogin,
              child: const Text(
                'Login',
                style: TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.blue
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
