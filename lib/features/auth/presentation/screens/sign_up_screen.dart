// lib/features/auth/presentation/screens/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../widgets/password_field.dart';
import '../widgets/policy_acceptance_dialog.dart';

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

  // Set once the user has accepted the Terms of Service + Privacy Policy
  // via the acceptance dialog. Gates the "Create account" action.
  bool _acceptedPolicies = false;

  // Email verification code (OTP) entry, shown after a successful sign-up.
  // _otpLength MUST match the "Email OTP Length" set in Supabase Auth.
  static const int _otpLength = 8;
  final _otp = TextEditingController();
  String? _otpError;
  bool _resending = false;

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
    _otp.dispose();
    super.dispose();
  }

  // ---------------- Validation ----------------

  bool get _step1Valid =>
      _agencyName.text.trim().isNotEmpty && _agencyState != null;

  // Reasonable email shape check: local@domain.tld
  static final _emailRe =
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  String? _validateStep2() {
    if (_fullName.text.trim().isEmpty) return 'Please enter your full name';
    if (!_emailRe.hasMatch(_email.text.trim())) {
      return 'Please enter a valid email address';
    }
    final phoneErr = _validatePhone(_phone.text);
    if (phoneErr != null) return phoneErr;
    if (_password.text.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (_password.text != _confirm.text) return "Passwords don't match";
    if (!_acceptedPolicies) {
      return 'Please review and accept the Terms of Service and Privacy Policy';
    }
    return null;
  }

  /// Validates a Nigerian phone number. Accepts 0XXXXXXXXXX (11 digits) or
  /// +234XXXXXXXXXX / 234XXXXXXXXXX. Returns null when valid.
  String? _validatePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return 'Please enter your phone number';
    final local = RegExp(r'^0[789]\d{9}$'); // 0803..., 0701..., 0901...
    final intl = RegExp(r'^\+?234[789]\d{9}$'); // +2348..., 234701...
    if (local.hasMatch(digits) || intl.hasMatch(digits)) return null;
    return 'Enter a valid Nigerian phone number (e.g. 0803 123 4567)';
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

  // ---------- Email code entry state ----------

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
            'Enter your code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We sent a $_otpLength-digit code to ${_confirmationEmail ?? "your email"}. "
              "Enter it below to activate your account.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: _otpLength,
          autofocus: true,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            hintText: '-' * _otpLength,
            hintStyle:
                const TextStyle(letterSpacing: 8, color: AppColors.border),
          ),
          onChanged: (v) {
            if (_otpError != null) setState(() => _otpError = null);
            if (v.length == _otpLength) _verifyOtp();
          },
          onSubmitted: (_) => _verifyOtp(),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 4),
          Text(
            _otpError!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verify & continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resending ? null : _resendOtp,
          child: Text(_resending ? 'Sending…' : "Didn't get it? Resend code"),
        ),
        TextButton(
          onPressed: () => setState(() {
            _needsEmailConfirmation = false;
            _otp.clear();
            _otpError = null;
          }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }

  // ---------- Email code (OTP) verification ----------

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.length < _otpLength) {
      setState(
          () => _otpError = 'Enter the $_otpLength-digit code from your email');
      return;
    }
    setState(() {
      _loading = true;
      _otpError = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifySignupCode(
            email: _confirmationEmail ?? _email.text.trim(),
            code: code,
          );
      // Confirmed + signed in. Make sure the agency/profile rows exist
      // (the trigger usually creates them at sign-up), then enter the app.
      await ref.read(authRepositoryProvider).completeSignupIfNeeded(
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
            agencyName: _agencyName.text.trim(),
            agencyPhone: _agencyPhone.text.trim(),
            agencyState: _agencyState ?? '',
            agencyRcNumber: _rcNumber.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome to Lintel, ${_fullName.text.trim()}!'),
          backgroundColor: AppColors.brand,
        ),
      );
      context.go('/');
    } on AuthException catch (e) {
      setState(() => _otpError = _readableOtpError(e));
    } catch (e) {
      setState(() => _otpError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _readableOtpError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('expired')) {
      return 'That code has expired. Tap "Resend code" for a new one.';
    }
    if (m.contains('invalid') || m.contains('token') || m.contains('otp')) {
      return 'That code is incorrect. Please check it and try again.';
    }
    return e.message;
  }

  Future<void> _resendOtp() async {
    setState(() {
      _resending = true;
      _otpError = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupCode(_confirmationEmail ?? _email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
    } on AuthException catch (e) {
      setState(() => _otpError = e.message);
    } catch (e) {
      setState(() => _otpError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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
        label: 'Phone *',
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
      _policyAcceptanceTile(),
    ];
  }

  Widget _policyAcceptanceTile() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _loading ? null : _openPolicyDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _acceptedPolicies
                ? AppColors.brand.withOpacity(0.06)
                : AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _acceptedPolicies ? AppColors.brand : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _acceptedPolicies
                    ? Icons.check_circle
                    : Icons.assignment_outlined,
                size: 20,
                color: _acceptedPolicies ? AppColors.brand : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _acceptedPolicies
                      ? "You've accepted the Terms of Service and Privacy Policy"
                      : 'Read & accept the Terms of Service and Privacy Policy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color:
                        _acceptedPolicies ? AppColors.brand : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _acceptedPolicies ? 'Review' : 'Open',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPolicyDialog() async {
    final accepted = await showPolicyAcceptanceDialog(context);
    if (!mounted) return;
    if (accepted) {
      setState(() {
        _acceptedPolicies = true;
        _error = null;
      });
    }
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
          if (obscure)
            PasswordField(
              controller: controller,
              hint: hint,
              isDense: true,
              onChanged: onChanged,
            )
          else
            TextField(
              controller: controller,
              keyboardType: keyboardType,
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
            isExpanded: true,
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