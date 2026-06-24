// lib/features/email/presentation/widgets/new_campaign_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../../data/repositories/email_audiences_repository.dart';
import '../../providers/email_audiences_providers.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _clientStatesProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).getClientStates();
});

class NewCampaignDialog extends ConsumerStatefulWidget {
  const NewCampaignDialog({
    super.key,
    this.initialHtml,
    this.initialHtmlMode = false,
  });

  final String? initialHtml;
  final bool initialHtmlMode;

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

  DateTime? _scheduledFor;

  bool _sending = false;
  bool _htmlMode = false;
  String? _error;

  ({String campaignId, int totalRecipients, int sentCount, int failedCount})?
  _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialHtml != null) {
      _bodyCtrl.text = widget.initialHtml!;
      _htmlMode = widget.initialHtmlMode;
    }
    _refreshCount();
  }

  @override
  void dispose() {
    _campaignNameCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _applyAudience(EmailAudience a) {
    setState(() {
      final t = (a.filter['type'] as String?) ?? 'all';
      _filterType = t;
      _selectedStates.clear();
      if (t == 'by_state') {
        _selectedStates.addAll(
            (a.filter['states'] as List?)?.cast<String>() ?? const []);
      }
    });
    _refreshCount();
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

  String _formatScheduled() {
    final s = _scheduledFor!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = s.hour.toString().padLeft(2, '0');
    final m = s.minute.toString().padLeft(2, '0');
    return '${s.day} ${months[s.month - 1]} · $h:$m';
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledFor ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      picked.year, picked.month, picked.day,
      time.hour, time.minute,
    );
    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Scheduled time must be in the future'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _scheduledFor = combined);
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
      final html = _renderHtml(body);

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

  Future<void> _schedule() async {
    final name = _campaignNameCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (name.isEmpty || subject.isEmpty || body.isEmpty) {
      setState(() => _error = 'Name, subject, and body are all required');
      return;
    }
    if (_scheduledFor == null) {
      setState(() => _error = 'Pick a scheduled time first');
      return;
    }
    if (_filterType == 'by_state' && _selectedStates.isEmpty) {
      setState(() => _error = 'Pick at least one state');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final html = _renderHtml(body);

      final result = await ref.read(_emailRepoProvider).scheduleCampaign(
        campaignName: name,
        subject: subject,
        html: html,
        filter: _buildFilter(),
        scheduledFor: _scheduledFor!,
      );

      setState(() => _result = (
      campaignId: result.campaignId,
      totalRecipients: result.recipientCount,
      sentCount: 0,
      failedCount: 0,
      ));
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Renders the editor body to send-ready HTML. In HTML mode the body is the
  /// raw HTML the user authored; in Simple mode we wrap their text in a basic
  /// shell and turn newlines into <br>.
  String _renderHtml(String body) {
    if (_htmlMode) return body;
    return '''
        <div style="font-family: Arial, sans-serif; font-size: 14px; line-height: 1.6; color: #222;">
          ${body.replaceAll('\n', '<br>')}
        </div>
      ''';
  }

  Future<void> _sendTest() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      setState(() => _error = 'Add a subject and message before sending a test');
      return;
    }

    var toEmail = SupabaseService.client.auth.currentUser?.email ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send a test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We'll send this draft to one address so you can preview it. "
              "It won't create a campaign or affect your stats.",
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: toEmail,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              onChanged: (v) => toEmail = v,
              decoration: const InputDecoration(
                labelText: 'Send test to',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send test'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    toEmail = toEmail.trim();
    if (toEmail.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(_emailRepoProvider).sendTestEmail(
            toEmail: toEmail,
            subject: subject,
            html: _renderHtml(body),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Test sent to $toEmail'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
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
                        helper:
                        'Only you see this. e.g. "Q3 payment reminder"'),
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
                        helper:
                        'Personalise with {{first_name}}, {{last_name}} or {{name}}.'),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Simple',
                              style: TextStyle(fontSize: 12)),
                          selected: !_htmlMode,
                          onSelected: (_) =>
                              setState(() => _htmlMode = false),
                          selectedColor: AppColors.brandLight,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('HTML',
                              style: TextStyle(fontSize: 12)),
                          selected: _htmlMode,
                          onSelected: (_) =>
                              setState(() => _htmlMode = true),
                          selectedColor: AppColors.brandLight,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: _htmlMode ? 16 : 8,
                      minLines: 5,
                      style: _htmlMode
                          ? const TextStyle(
                              fontFamily: 'monospace', fontSize: 13)
                          : null,
                      decoration: InputDecoration(
                        hintText: _htmlMode
                            ? '<h1>Hello {{first_name}}</h1>\n<p>Your message…</p>'
                            : 'Hi {{name}},\n\n...',
                        isDense: true,
                      ),
                    ),
                    if (_htmlMode) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Write or paste full HTML. Placeholders like '
                        '{{first_name}} still work. Use "Send test" to preview '
                        'it in your inbox.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.muted),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _recipientCountBadge()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _pickSchedule,
                        icon: const Icon(Icons.schedule, size: 14),
                        label: Text(_scheduledFor == null
                            ? 'Schedule…'
                            : _formatScheduled()),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _sendTest,
                        icon: const Icon(Icons.forward_to_inbox, size: 14),
                        label: const Text('Send test'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 6),
                      if (_scheduledFor != null) ...[
                        FilledButton.icon(
                          onPressed: _sending ? null : _schedule,
                          icon: _sending
                              ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Icon(Icons.schedule, size: 14),
                          label:
                          Text(_sending ? 'Scheduling…' : 'Schedule'),
                        ),
                      ] else ...[
                        FilledButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Icon(Icons.send, size: 14),
                          label:
                          Text(_sending ? 'Sending…' : 'Send now'),
                        ),
                      ],
                    ],
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
    final audiencesAsync = ref.watch(emailAudiencesProvider);

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
              style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          audiencesAsync.maybeWhen(
            data: (auds) => auds.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DropdownButtonFormField<String>(
                      value: null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Load a saved audience',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final a in auds)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        _applyAudience(
                            auds.firstWhere((x) => x.id == id));
                      },
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          _radioOption('all', 'All clients with an email'),
          _radioOption(
              'has_active_contract', 'Clients with an active contract'),
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
    final isScheduled = _scheduledFor != null;
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
                  isScheduled
                      ? Icons.schedule
                      : (allOk ? Icons.check_circle : Icons.error),
                  size: 40,
                  color: isScheduled
                      ? AppColors.brand
                      : (allOk ? AppColors.brand : AppColors.warn),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isScheduled
                      ? 'Campaign scheduled'
                      : (allOk
                      ? 'Campaign sent'
                      : 'Campaign sent with errors'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    if (isScheduled) ...[
                      Text(
                        'Will send to ${r.totalRecipients} recipient${r.totalRecipients == 1 ? "" : "s"}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled for ${_formatScheduled()}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ] else ...[
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