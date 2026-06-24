// lib/features/email/presentation/widgets/automation_editor_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

class AutomationEditorDialog extends ConsumerStatefulWidget {
  const AutomationEditorDialog({super.key});

  @override
  ConsumerState<AutomationEditorDialog> createState() =>
      _AutomationEditorDialogState();
}

class _AutomationEditorDialogState
    extends ConsumerState<AutomationEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _offsetCtrl = TextEditingController(text: '0');

  String _triggerType = 'client_birthday';
  bool _saving = false;
  String? _error;

  bool get _needsOffset =>
      _triggerType == 'days_before_installment_due' ||
          _triggerType == 'days_after_installment_overdue' ||
          _triggerType == 'days_after_client_onboarded';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _offsetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (name.isEmpty || subject.isEmpty || body.isEmpty) {
      setState(() => _error = 'Name, subject, and message are all required');
      return;
    }

    final offsetDays =
    _needsOffset ? int.tryParse(_offsetCtrl.text) ?? 0 : 0;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Wrap plaintext body in HTML
      final html = '''
        <div style="font-family: Arial, sans-serif; font-size: 14px; line-height: 1.6; color: #222;">
          ${body.replaceAll('\n', '<br>')}
        </div>
      ''';

      await ref.read(_emailRepoProvider).createAutomation(
        name: name,
        triggerType: _triggerType,
        triggerOffsetDays: offsetDays,
        triggerTime: '09:00:00',
        subjectTemplate: subject,
        bodyHtmlTemplate: html,
        isActive: true,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyTemplate(String triggerType) {
    setState(() {
      _triggerType = triggerType;
      _offsetCtrl.text = switch (triggerType) {
        'days_before_installment_due' => '3',
        'days_after_installment_overdue' => '1',
        'days_after_client_onboarded' => '1',
        _ => '0',
      };

      switch (triggerType) {
        case 'client_birthday':
          _nameCtrl.text = 'Birthday greeting';
          _subjectCtrl.text = 'Happy birthday, {{first_name}}! 🎉';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nThe whole team here wishes you a very happy birthday! '
              'Thank you for being part of our family.\n\nWith warm wishes,';
        case 'days_before_installment_due':
          _nameCtrl.text = '3-day installment reminder';
          _subjectCtrl.text = 'Reminder: Your installment is due soon';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nThis is a friendly reminder that your next installment is '
              'due in a few days. Please ensure your payment is made on time.\n\nThank you,';
        case 'days_after_installment_overdue':
          _nameCtrl.text = 'Overdue follow-up';
          _subjectCtrl.text = 'Action required: Your installment is overdue';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nWe noticed your installment is now overdue. Please make '
              'your payment as soon as possible to avoid any late charges. If you have '
              'any concerns, please reach out.\n\nWith care,';
        case 'contract_anniversary':
          _nameCtrl.text = 'Contract anniversary';
          _subjectCtrl.text = 'Celebrating your milestone with us!';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nIt\'s been another year since you signed your contract '
              'with us. Thank you for your continued trust!\n\nWarm regards,';
        case 'days_after_client_onboarded':
          _nameCtrl.text = 'Welcome follow-up';
          _subjectCtrl.text = 'Welcome to our family, {{first_name}}';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nIt\'s been a day since you joined us. We just wanted to '
              'say hi and let you know we\'re here if you need anything.\n\nBest,';
        case 'on_contract_signed':
          _nameCtrl.text = 'Contract signing confirmation';
          _subjectCtrl.text = 'Your contract is officially signed';
          _bodyCtrl.text =
          'Hi {{first_name}},\n\nCongratulations! Your contract has been signed. We\'re '
              'thrilled to have you on this journey with us.\n\nThanks,';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New automation',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Lintel will run this rule once a day, sending emails to matching clients.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Trigger'),
                    const SizedBox(height: 4),
                    _triggerPicker(),
                    const SizedBox(height: 14),

                    if (_needsOffset) ...[
                      _label(
                        _triggerType == 'days_before_installment_due'
                            ? 'Days before due date'
                            : _triggerType == 'days_after_installment_overdue'
                            ? 'Days after overdue'
                            : 'Days after onboarded',
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _offsetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _label('Rule name *',
                        helper: 'Only you see this. e.g. "3-day reminder"'),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(isDense: true),
                    ),
                    const SizedBox(height: 14),

                    _label('Subject *'),
                    TextField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(isDense: true),
                    ),
                    const SizedBox(height: 14),

                    _label('Message *',
                        helper:
                        'Use {{name}} for full name or {{first_name}} for first name only.'),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 8,
                      minLines: 5,
                      decoration: const InputDecoration(isDense: true),
                    ),

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
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 14),
                    label: Text(_saving ? 'Saving…' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _triggerPicker() {
    final options = [
      ('client_birthday', '🎂 Client birthday',
      'Send on each client\'s birthday'),
      ('days_before_installment_due', '⏰ Before installment due',
      'Remind clients N days before payment'),
      ('days_after_installment_overdue', '⚠️ After overdue',
      'Follow up N days after a missed payment'),
      ('contract_anniversary', '🎉 Contract anniversary',
      'Celebrate yearly milestones'),
      ('days_after_client_onboarded', '👋 Welcome follow-up',
      'N days after a client is added'),
    ];

    return Column(
      children: [
        for (final (value, label, desc) in options)
          InkWell(
            onTap: () => _applyTemplate(value),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _triggerType == value
                    ? AppColors.brand.withOpacity(0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: _triggerType == value
                        ? AppColors.brand
                        : AppColors.border,
                    width: _triggerType == value ? 1 : 0.5),
              ),
              child: Row(
                children: [
                  Radio<String>(
                    value: value,
                    groupValue: _triggerType,
                    onChanged: (v) {
                      if (v != null) _applyTemplate(v);
                    },
                    materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(String text, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          if (helper != null)
            Text(helper,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}