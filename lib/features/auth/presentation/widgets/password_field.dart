// lib/features/auth/presentation/widgets/password_field.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A password TextField with a built-in show/hide eye toggle.
/// Used on both the sign-in and sign-up screens so the toggle behaves
/// identically everywhere.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;

  /// Floating label (sign-in style). Leave null to use [hint] only.
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// Called when the user presses Enter/Done in the field.
  final VoidCallback? onSubmitted;
  final bool isDense;
  final bool autofocus;

  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.isDense = false,
    this.autofocus = false,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted:
          widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: widget.isDense,
        suffixIcon: IconButton(
          splashRadius: 20,
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.muted,
          ),
          tooltip: _visible ? 'Hide password' : 'Show password',
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
