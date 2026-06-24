// lib/features/finances/presentation/screens/recurring_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../data/repositories/expenses_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../providers/expenses_providers.dart';
import '../../providers/recurring_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  Future<void> _openEditor(
      BuildContext context, WidgetRef ref, RecurringExpense? existing) async {
    await showDialog(
      context: context,
      builder: (_) => _RecurringEditorDialog(existing: existing),
    );
    ref.invalidate(recurringListProvider);
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref) async {
    try {
      final n = await ref.read(recurringRepoProvider).materializeDue();
      ref.invalidate(recurringListProvider);
      ref.invalidate(expensesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'Nothing due — all caught up.'
              : 'Generated $n expense${n == 1 ? '' : 's'}.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, RecurringExpense r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recurring rule?'),
        content: Text(
            '${r.category} · ${Formatters.naira(r.amountNgn)} · ${r.frequencyLabel}.'
            ' Expenses already generated are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recurringRepoProvider).delete(r.id);
    ref.invalidate(recurringListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringListProvider);
    final addBtn = FilledButton.icon(
      onPressed: () => _openEditor(context, ref, null),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New rule'),
    );
    final runBtn = OutlinedButton.icon(
      onPressed: () => _generateNow(context, ref),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Generate due now'),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.isMobile) ...[
            const _Title(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: runBtn),
              const SizedBox(width: 8),
              Expanded(child: addBtn),
            ]),
          ] else
            Row(
              children: [
                const Expanded(child: _Title()),
                runBtn,
                const SizedBox(width: 8),
                addBtn,
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: LintelLoader()),
              error: (e, _) => Center(
                child: Text('Failed to load rules: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (rules) {
                if (rules.isEmpty) return _empty(context, ref);
                return ListView.separated(
                  itemCount: rules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RuleRow(
                    rule: rules[i],
                    onEdit: () => _openEditor(context, ref, rules[i]),
                    onDelete: () => _confirmDelete(context, ref, rules[i]),
                    onToggle: (v) async {
                      await ref
                          .read(recurringRepoProvider)
                          .update(rules[i].id, active: v);
                      ref.invalidate(recurringListProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_repeat_outlined,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No recurring expenses yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
              'Set up rent, salaries or subscriptions once — they post automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context, ref, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New rule'),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recurring expenses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('Rules that post an expense automatically each period.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final RecurringExpense rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _RuleRow({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final r = rule;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(r.category,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(r.frequencyLabel,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.naira(r.amountNgn)} · '
                  '${r.active ? 'next ${Formatters.date(r.nextDue)}' : 'paused'}'
                  '${r.payee != null ? ' · ${r.payee}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: r.active,
            onChanged: onToggle,
            activeColor: AppColors.brand,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete',
            color: AppColors.danger,
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RecurringEditorDialog extends ConsumerStatefulWidget {
  final RecurringExpense? existing;
  const _RecurringEditorDialog({this.existing});

  @override
  ConsumerState<_RecurringEditorDialog> createState() =>
      _RecurringEditorDialogState();
}

class _RecurringEditorDialogState
    extends ConsumerState<_RecurringEditorDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _payee;
  late final TextEditingController _notes;
  late String _category;
  late String _frequency;
  late DateTime _startDate;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount =
        TextEditingController(text: e != null ? e.amountNgn.toString() : '');
    _payee = TextEditingController(text: e?.payee ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? kExpenseCategories.first;
    _frequency = e?.frequency ?? 'monthly';
    _startDate = e?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(recurringRepoProvider);
      if (widget.existing == null) {
        await repo.create(
          category: _category,
          amountNgn: amount,
          frequency: _frequency,
          startDate: _startDate,
          payee: _payee.text,
          notes: _notes.text,
        );
      } else {
        await repo.update(
          widget.existing!.id,
          category: _category,
          amountNgn: amount,
          frequency: _frequency,
          payee: _payee.text,
          notes: _notes.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(editing ? 'Edit recurring rule' : 'New recurring rule',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Amount (₦) *'),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 150000',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Category *'),
                    DropdownButtonFormField<String>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final c in kExpenseCategories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 14),
                    _label('Frequency *'),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final f in kRecurringFrequencies)
                          DropdownMenuItem(
                              value: f,
                              child: Text(recurringFrequencyLabel(f))),
                      ],
                      onChanged: (v) =>
                          setState(() => _frequency = v ?? _frequency),
                    ),
                    if (!editing) ...[
                      const SizedBox(height: 14),
                      _label('First due date *'),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(6),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(Formatters.date(_startDate),
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _label('Payee'),
                    TextField(
                      controller: _payee,
                      decoration: const InputDecoration(
                        hintText: 'Who gets paid (optional)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Notes'),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        isDense: true,
                      ),
                    ),
                    if (editing) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Changing the amount or category affects future '
                        'generated expenses only.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
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
                    top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: Text(_saving
                        ? 'Saving…'
                        : (editing ? 'Save' : 'Create rule')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
      );
}
