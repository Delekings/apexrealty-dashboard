// lib/features/auth/presentation/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../widgets/password_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
        _email.text.trim(),
        _password.text,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _legalLine(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('By continuing you agree to our ',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        _legalLink(context, 'Terms of Service', '/legal/terms'),
        const Text(' and ',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        _legalLink(context, 'Privacy Policy', '/legal/privacy'),
        const Text('.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _legalLink(BuildContext context, String label, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.brand,
              fontWeight: FontWeight.w500)),
    );
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
                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Lin',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const Text('tel',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand)),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Sign in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.go('/forgot-password'),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
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
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New to Lintel? ",
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: const Text(
                        'Create an account',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _legalLine(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}