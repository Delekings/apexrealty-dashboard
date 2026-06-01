// lib/features/staff/widgets/invite_staff_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/staff_repository.dart';

class InviteStaffDialog extends ConsumerStatefulWidget {
  const InviteStaffDialog({super.key});

  @override
  ConsumerState<InviteStaffDialog> createState() => _InviteStaffDialogState();
}

class _InviteStaffDialogState extends ConsumerState<InviteStaffDialog> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _commissionRate = TextEditingController(text: '5');

  String _role = 'agent';        // agent | manager | accountant
  bool _isExternal = false;
  bool _submitting = false;
  String? _error;
  bool _sent = false;

  bool get _showCommissionField =>
      _role == 'agent' && _isExternal;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final fullName = _fullName.text.trim();
    if (fullName.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Full name and valid email are required');
      return;
    }

    double? commission;
    if (_showCommissionField) {
      commission = double.tryParse(_commissionRate.text.trim());
      if (commission == null || commission < 0 || commission > 100) {
        setState(() => _error = 'Commission must be between 0 and 100');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(staffRepoProvider).invite(
        email: email,
        fullName: fullName,
        role: _role,
        isExternal: _isExternal,
        commissionRatePct: commission,
      );
      ref.invalidate(staffListProvider);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _sent ? _successView() : _formView(),
        ),
      ),
    );
  }

  Widget _formView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Invite team member',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _submitting
                    ? null
                    : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'They\'ll get an email from Lintel to set their password and join your agency.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _label('Full name *'),
          TextField(
            controller: _fullName,
            decoration: const InputDecoration(hintText: 'e.g. Jane Adebayo'),
          ),
          const SizedBox(height: 12),
          _label('Email *'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'jane@example.com'),
          ),
          const SizedBox(height: 12),
          _label('Role *'),
          DropdownButtonFormField<String>(
            value: _role,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(
                value: 'agent',
                child: Text('Sales agent — closes deals'),
              ),
              DropdownMenuItem(
                value: 'manager',
                child: Text('Manager — runs operations'),
              ),
              DropdownMenuItem(
                value: 'accountant',
                child: Text('Accountant — handles payments & receipts'),
              ),
            ],
            onChanged: (v) => setState(() {
              _role = v ?? 'agent';
              if (_role != 'agent') _isExternal = false;
            }),
          ),
          if (_role == 'agent') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _isExternal,
                  onChanged: (v) =>
                      setState(() => _isExternal = v ?? false),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('External (commission only)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        'They refer clients, get paid commission when client completes payment. Not an employee.',
                        style:
                        TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_showCommissionField) ...[
            const SizedBox(height: 12),
            _label('Commission rate (%)'),
            TextField(
              controller: _commissionRate,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  hintText: '5',
                  suffixText: '%',
                  isDense: true),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 14),
                label: Text(_submitting ? 'Sending…' : 'Send invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_rounded,
            color: AppColors.brand, size: 40),
        const SizedBox(height: 12),
        const Text('Invitation sent',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          '${_email.text.trim()} will receive an email to join your agency. The invite expires in 24 hours.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  );
}