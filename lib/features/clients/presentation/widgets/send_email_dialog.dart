// lib/features/clients/presentation/widgets/send_email_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/clients_repository.dart';
import '../../../../data/repositories/email_repository.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

class SendEmailDialog extends ConsumerStatefulWidget {
  final ClientDetail detail;

  const SendEmailDialog({super.key, required this.detail});

  @override
  ConsumerState<SendEmailDialog> createState() => _SendEmailDialogState();
}

class _SendEmailDialogState extends ConsumerState<SendEmailDialog> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _sending = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (subject.isEmpty) {
      setState(() => _error = 'Subject is required');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Message body is required');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final clientName = widget.detail.client.fullName;
      final nameParts = clientName.trim().split(RegExp(r'\s+'));
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.last : '';
      final personalisedBody = body
          .replaceAll('{{name}}', clientName)
          .replaceAll('{{first_name}}', firstName)
          .replaceAll('{{last_name}}', lastName);
      // Wrap plain-text in basic HTML so line breaks render
      final html = '''
        <div style="font-family: Arial, sans-serif; font-size: 14px; line-height: 1.6; color: #222;">
          ${personalisedBody.replaceAll('\n', '<br>')}
        </div>
      ''';

      await ref.read(_emailRepoProvider).sendToClient(
        clientId: widget.detail.client.id,
        subject: subject,
        html: html,
      );

      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _sentView();

    final c = widget.detail.client;
    final hasEmail = c.email != null && c.email!.isNotEmpty;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send email',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text(
                            'Sends through Lintel using your agency name.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Recipient
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To: ${c.fullName}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              hasEmail
                                  ? c.email!
                                  : 'No email on file — cannot send',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasEmail
                                    ? AppColors.muted
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Subject
                _label('Subject *'),
                TextField(
                  controller: _subjectCtrl,
                  enabled: !_sending && hasEmail,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Your installment is due next week',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Body
                _label('Message *',
                    helper:
                    'Personalise with {{name}}, {{first_name}}, or {{last_name}}.'),
                TextField(
                  controller: _bodyCtrl,
                  enabled: !_sending && hasEmail,
                  maxLines: 10,
                  minLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Hi {{name}},\n\nJust a quick reminder...',
                    isDense: true,
                  ),
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

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: (_sending || !hasEmail) ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 14),
                      label: Text(_sending ? 'Sending…' : 'Send'),
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

  Widget _sentView() {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.check_circle,
                    size: 40, color: AppColors.brand),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Email sent',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Delivered to ${widget.detail.client.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
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