// lib/features/auth/presentation/screens/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

const _nigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
  'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
  'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
  'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
  'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  // Set when sign-up succeeded but the user needs to confirm their email
  // before being able to sign in. (i.e. "Confirm email" is ON in Supabase.)
  bool _needsEmailConfirmation = false;
  String? _confirmationEmail;

  // Agency fields
  final _agencyName = TextEditingController();
  final _agencyPhone = TextEditingController();
  String? _agencyState;
  final _rcNumber = TextEditingController();

  // Admin user fields
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _agencyName.dispose();
    _agencyPhone.dispose();
    _rcNumber.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // ---------------- Validation ----------------

  bool get _step1Valid =>
      _agencyName.text.trim().isNotEmpty && _agencyState != null;

  String? _validateStep2() {
    if (_fullName.text.trim().isEmpty) return 'Please enter your full name';
    if (!_email.text.contains('@')) return 'Please enter a valid email';
    if (_password.text.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (_password.text != _confirm.text) return "Passwords don't match";
    return null;
  }

  // ---------------- Submit ----------------

  Future<void> _submit() async {
    final err = _validateStep2();
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).signUpAgencyAdmin(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        agencyName: _agencyName.text.trim(),
        agencyPhone: _agencyPhone.text.trim(),
        agencyState: _agencyState!,
        agencyRcNumber: _rcNumber.text.trim(),
      );

      if (!mounted) return;

      if (!result.needsEmailConfirmation) {
        // Signed in immediately — go to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to Lintel, ${_fullName.text.trim()}!'),
            backgroundColor: AppColors.brand,
          ),
        );
        context.go('/');
      } else {
        // Email confirmation required — show the "check your inbox" state
        setState(() {
          _needsEmailConfirmation = true;
          _confirmationEmail = result.email;
        });
      }
    } on AuthException catch (e) {
      setState(() => _error = _readableAuthError(e));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _readableAuthError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('user already')) {
      return 'An account with this email already exists. '
          'Try signing in instead.';
    }
    if (m.contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (m.contains('invalid email')) {
      return "That email address doesn't look valid.";
    }
    return e.message;
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _needsEmailConfirmation
                ? _confirmationContent()
                : _signupContent(),
          ),
        ),
      ),
    );
  }

  // ---------- "Check your email" state ----------

  Widget _confirmationContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logo(),
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.brandLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.brand,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Check your email',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We sent a confirmation link to ${_confirmationEmail ?? "your email"}. "
              "Click the link to activate your account, then sign in.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/signin'),
          child: const Text('Go to sign in'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _needsEmailConfirmation = false;
          }),
          child: const Text(
            "Didn't receive the email? Try a different address",
          ),
        ),
      ],
    );
  }

  // ---------- Form state ----------

  Widget _signupContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logo(),
        const SizedBox(height: 24),
        Text(
          _step == 0 ? 'Set up your agency' : 'Create your admin account',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _step == 0
              ? 'Tell us about your real estate company. You can change these later.'
              : "You'll be the admin for ${_agencyName.text.trim()}.",
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        _stepperDots(),
        const SizedBox(height: 24),
        if (_step == 0) ..._step1Fields() else ..._step2Fields(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _errorBox(),
        ],
        const SizedBox(height: 20),
        _actionButtons(),
        const SizedBox(height: 16),
        _signInLink(),
      ],
    );
  }

  // ---------- Small pieces ----------

  Widget _logo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Lin',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const Text(
          'tel',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }

  Widget _stepperDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(filled: true),
        Container(
          width: 24,
          height: 2,
          color: _step >= 1 ? AppColors.brand : AppColors.border,
        ),
        _dot(filled: _step >= 1),
      ],
    );
  }

  Widget _dot({required bool filled}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.brand : AppColors.bg2,
        border: Border.all(
          color: filled ? AppColors.brand : AppColors.border,
        ),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    if (_step == 0) {
      return FilledButton(
        onPressed: _step1Valid
            ? () => setState(() {
          _step = 1;
          _error = null;
        })
            : null,
        child: const Text('Continue'),
      );
    }
    return Column(
      children: [
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Text('Create account'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
            _step = 0;
            _error = null;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _signInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        GestureDetector(
          onTap: () => context.go('/signin'),
          child: const Text(
            'Sign in',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.brand,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Field groups ----------

  List<Widget> _step1Fields() {
    return [
      _field(
        label: 'Agency name *',
        controller: _agencyName,
        hint: 'e.g. Cosmopolitan Homes Ltd',
        onChanged: (_) => setState(() {}),
      ),
      _field(
        label: 'Agency phone',
        controller: _agencyPhone,
        hint: '080X XXX XXXX',
        keyboardType: TextInputType.phone,
      ),
      _stateDropdown(),
      _field(
        label: 'RC number',
        controller: _rcNumber,
        hint: 'CAC registration (optional)',
      ),
    ];
  }

  List<Widget> _step2Fields() {
    return [
      _field(
        label: 'Your full name *',
        controller: _fullName,
        hint: 'e.g. Adaeze Okoro',
        onChanged: (_) => setState(() {}),
      ),
      _field(
        label: 'Email *',
        controller: _email,
        hint: 'you@youragency.com',
        keyboardType: TextInputType.emailAddress,
      ),
      _field(
        label: 'Phone',
        controller: _phone,
        hint: '080X XXX XXXX',
        keyboardType: TextInputType.phone,
      ),
      _field(
        label: 'Password *',
        controller: _password,
        obscure: true,
        hint: 'At least 6 characters',
      ),
      _field(
        label: 'Confirm password *',
        controller: _confirm,
        obscure: true,
      ),
    ];
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'State *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _agencyState,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final s in _nigerianStates)
                DropdownMenuItem<String>(
                  value: s,
                  child: Text(
                    s,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _agencyState = v),
          ),
        ],
      ),
    );
  }
}