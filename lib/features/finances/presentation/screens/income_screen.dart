// lib/features/finances/presentation/screens/income_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../data/repositories/income_repository.dart';
import '../../providers/income_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  Future<void> _openEditor(
      BuildContext context, WidgetRef ref, OtherIncome? existing) async {
    await showDialog(
      context: context,
      builder: (_) => _IncomeEditorDialog(existing: existing),
    );
    ref.invalidate(incomeProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, OtherIncome e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete income entry?'),
        content: Text(
            '${Formatters.naira(e.amountNgn)} · ${e.source}'
            '${e.payer != null ? ' · ${e.payer}' : ''} will be removed.'),
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
    try {
      await ref.read(incomeRepoProvider).delete(e.id);
      ref.invalidate(incomeProvider);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomeProvider);
    final addBtn = FilledButton.icon(
      onPressed: () => _openEditor(context, ref, null),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add income'),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.isMobile) ...[
            const _Title(),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: addBtn),
          ] else
            Row(
              children: [
                const Expanded(child: _Title()),
                addBtn,
              ],
            ),
          const SizedBox(height: 16),

          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: LintelLoader()),
              error: (e, _) => Center(
                child: Text('Failed to load income: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (items) {
                if (items.isEmpty) return _empty(context, ref);
                final total = items.fold<num>(0, (s, e) => s + e.amountNgn);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${items.length} entr${items.length == 1 ? 'y' : 'ies'} · '
                        '${Formatters.naira(total)} total',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _IncomeRow(
                          item: items[i],
                          onEdit: () => _openEditor(context, ref, items[i]),
                          onDelete: () => _confirmDelete(context, ref, items[i]),
                        ),
                      ),
                    ),
                  ],
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
          const Icon(Icons.savings_outlined, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No other income logged yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
              'Record income that isn\'t a sale payment — fees, commission, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context, ref, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add income'),
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
        Text('Other income',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('Income that isn\'t a sale payment — fees, commission, interest.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final OtherIncome item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IncomeRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final e = item;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
                        child: Text(e.source,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (e.payer != null && e.payer!.isNotEmpty) ...[
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.muted)),
                        Flexible(
                          child: Text(e.payer!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.text),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.date(e.receivedOn) +
                        (e.notes != null && e.notes!.isNotEmpty
                            ? ' · ${e.notes}'
                            : ''),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(Formatters.naira(e.amountNgn),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: AppColors.danger,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeEditorDialog extends ConsumerStatefulWidget {
  final OtherIncome? existing;
  const _IncomeEditorDialog({this.existing});

  @override
  ConsumerState<_IncomeEditorDialog> createState() =>
      _IncomeEditorDialogState();
}

class _IncomeEditorDialogState extends ConsumerState<_IncomeEditorDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _payer;
  late final TextEditingController _notes;
  late String _source;
  late DateTime _receivedOn;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount =
        TextEditingController(text: e != null ? e.amountNgn.toString() : '');
    _payer = TextEditingController(text: e?.payer ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _source = e?.source ?? kIncomeSources.first;
    _receivedOn = e?.receivedOn ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _payer.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedOn,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _receivedOn = picked);
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
      final repo = ref.read(incomeRepoProvider);
      if (widget.existing == null) {
        await repo.create(
          source: _source,
          amountNgn: amount,
          receivedOn: _receivedOn,
          payer: _payer.text,
          notes: _notes.text,
        );
      } else {
        await repo.update(
          widget.existing!.id,
          source: _source,
          amountNgn: amount,
          receivedOn: _receivedOn,
          payer: _payer.text,
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
              child: Text(editing ? 'Edit income' : 'Add income',
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
                        hintText: 'e.g. 50000',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Source *'),
                    DropdownButtonFormField<String>(
                      value: _source,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final s in kIncomeSources)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _source = v ?? _source),
                    ),
                    const SizedBox(height: 14),
                    _label('Date *'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(Formatters.date(_receivedOn),
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Payer'),
                    TextField(
                      controller: _payer,
                      decoration: const InputDecoration(
                        hintText: 'Who paid (optional)',
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
                        : (editing ? 'Save' : 'Add income')),
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
