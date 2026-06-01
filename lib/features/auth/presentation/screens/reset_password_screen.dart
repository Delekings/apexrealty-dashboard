// lib/features/auth/presentation/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final pwd = _password.text;
    final cnf = _confirm.text;

    if (pwd.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (pwd != cnf) {
      setState(() => _error = 'Passwords don\'t match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(pwd);
      if (!mounted) return;
      // Supabase signs the user in automatically after updateUser.
      // Push them to the dashboard.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Welcome back!')),
      );
      context.go('/');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
                const Text('Set a new password',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                  'Choose a new password for your Lintel account. Must be at least 8 characters.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
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
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}