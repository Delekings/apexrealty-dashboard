// lib/features/auth/presentation/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      // We deliberately don't expose whether the email exists or not.
      // Show success even on (some) errors to prevent account enumeration.
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.home_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Lin',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const Text('tel',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand)),
                  ],
                ),
                const SizedBox(height: 32),
                if (_sent) ..._successContent() else ..._formContent(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/signin'),
                      child: const Text(
                        '← Back to sign in',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formContent() {
    return [
      const Text('Reset your password',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text(
        'Enter the email tied to your Lintel account. We\'ll send you a link to set a new password.',
        style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
        onSubmitted: (_) => _submit(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.danger)),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Text('Send reset link'),
      ),
    ];
  }

  List<Widget> _successContent() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mark_email_read_rounded,
                color: AppColors.brand, size: 28),
            const SizedBox(height: 12),
            const Text('Check your email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'If an account exists for ${_email.text.trim()}, we\'ve sent a password reset link. It expires in 1 hour.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Don\'t see it? Check your spam folder.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ];
  }
}