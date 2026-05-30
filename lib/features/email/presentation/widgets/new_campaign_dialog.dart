// lib/features/email/presentation/widgets/new_campaign_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _clientStatesProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).getClientStates();
});

class NewCampaignDialog extends ConsumerStatefulWidget {
  const NewCampaignDialog({super.key});

  @override
  ConsumerState<NewCampaignDialog> createState() =>
      _NewCampaignDialogState();
}

class _NewCampaignDialogState extends ConsumerState<NewCampaignDialog> {
  final _campaignNameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _filterType = 'all';
  final Set<String> _selectedStates = {};

  int? _recipientCount;
  bool _countingRecipients = false;

  bool _sending = false;
  String? _error;

  ({String campaignId, int totalRecipients, int sentCount, int failedCount})?
  _result;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  @override
  void dispose() {
    _campaignNameCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFilter() {
    switch (_filterType) {
      case 'by_state':
        return {'type': 'by_state', 'states': _selectedStates.toList()};
      case 'has_active_contract':
        return {'type': 'has_active_contract'};
      case 'has_overdue':
        return {'type': 'has_overdue'};
      case 'all':
      default:
        return {'type': 'all'};
    }
  }

  Future<void> _refreshCount() async {
    setState(() {
      _countingRecipients = true;
      _recipientCount = null;
    });
    try {
      final n = await ref
          .read(_emailRepoProvider)
          .previewRecipientCount(_buildFilter());
      if (!mounted) return;
      setState(() => _recipientCount = n);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipientCount = -1);
    } finally {
      if (mounted) setState(() => _countingRecipients = false);
    }
  }

  Future<void> _send() async {
    final name = _campaignNameCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Campaign name is required');
      return;
    }
    if (subject.isEmpty) {
      setState(() => _error = 'Subject is required');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Message body is required');
      return;
    }
    if (_recipientCount == null || _recipientCount! <= 0) {
      setState(() => _error = 'No eligible recipients for this filter');
      return;
    }
    if (_filterType == 'by_state' && _selectedStates.isEmpty) {
      setState(() => _error = 'Pick at least one state');
      return;
    }

    final confirmed = await _confirmSend();
    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // Wrap body in HTML; rate limiting is server-side
      final html = '''
        <div style="font-family: Arial, sans-serif; font-size: 14px; line-height: 1.6; color: #222;">
          ${body.replaceAll('\n', '<br>')}
        </div>
      ''';

      final result = await ref.read(_emailRepoProvider).sendBulk(
        campaignName: name,
        subject: subject,
        html: html,
        filter: _buildFilter(),
      );

      setState(() => _result = result);
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _confirmSend() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Send to $_recipientCount recipients?'),
      content: const Text(
        'This will queue and send emails immediately. You cannot undo this. '
            'Each recipient will receive one email with their name personalised.',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send now')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _resultView();
    return _composeView();
  }

  Widget _composeView() {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
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
                        Text('New campaign',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Compose an email and send it to multiple clients at once.',
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
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Internal campaign name *',
                        helper: 'Only you see this. e.g. "Q3 payment reminder"'),
                    TextField(
                      controller: _campaignNameCtrl,
                      decoration: const InputDecoration(isDense: true),
                    ),
                    const SizedBox(height: 14),

                    _recipientPicker(),
                    const SizedBox(height: 14),

                    _label('Subject *'),
                    TextField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Your installment is due next week',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    _label('Message *',
                        helper: 'Use {{name}} for personalisation.'),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 8,
                      minLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Hi {{name}},\n\n...',
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
                children: [
                  Expanded(child: _recipientCountBadge()),
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 14),
                    label: Text(_sending ? 'Sending…' : 'Send now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientCountBadge() {
    String text;
    Color color;
    if (_countingRecipients) {
      text = 'Counting recipients…';
      color = AppColors.muted;
    } else if (_recipientCount == null || _recipientCount == -1) {
      text = 'Could not count';
      color = AppColors.danger;
    } else if (_recipientCount == 0) {
      text = 'No eligible recipients';
      color = AppColors.warn;
    } else {
      text =
      'Will send to $_recipientCount recipient${_recipientCount == 1 ? "" : "s"}';
      color = AppColors.brand;
    }
    return Text(
      text,
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: color),
    );
  }

  Widget _recipientPicker() {
    final statesAsync = ref.watch(_clientStatesProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recipients *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _radioOption('all', 'All clients with an email'),
          _radioOption('has_active_contract', 'Clients with an active contract'),
          _radioOption('has_overdue', 'Clients with overdue installments'),
          _radioOption('by_state', 'Clients in specific state(s)'),
          if (_filterType == 'by_state') ...[
            const SizedBox(height: 8),
            statesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Could not load states: $e',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.danger)),
              data: (states) {
                if (states.isEmpty) {
                  return const Text(
                    'No clients have a state set.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.muted),
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in states)
                      FilterChip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 11)),
                        selected: _selectedStates.contains(s),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedStates.add(s);
                            } else {
                              _selectedStates.remove(s);
                            }
                          });
                          _refreshCount();
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _radioOption(String value, String label) {
    return InkWell(
      onTap: () {
        setState(() => _filterType = value);
        _refreshCount();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _filterType,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _filterType = v);
                  _refreshCount();
                }
              },
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
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

  Widget _resultView() {
    final r = _result!;
    final allOk = r.failedCount == 0;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(
                  allOk ? Icons.check_circle : Icons.error,
                  size: 40,
                  color: allOk ? AppColors.brand : AppColors.warn,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  allOk ? 'Campaign sent' : 'Campaign sent with errors',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${r.sentCount} of ${r.totalRecipients} delivered',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (r.failedCount > 0)
                      Text(
                        '${r.failedCount} failed',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger),
                      ),
                  ],
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
}