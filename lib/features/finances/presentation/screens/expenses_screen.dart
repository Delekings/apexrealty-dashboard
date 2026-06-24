// lib/features/finances/presentation/screens/expenses_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/single_file_picker.dart';
import '../../../../data/repositories/expenses_repository.dart';
import '../../providers/expenses_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _openEditor(
      BuildContext context, WidgetRef ref, Expense? existing) async {
    await showDialog(
      context: context,
      builder: (_) => _ExpenseEditorDialog(existing: existing),
    );
    ref.invalidate(expensesProvider);
  }

  Future<void> _viewReceipt(
      BuildContext context, WidgetRef ref, Expense e) async {
    try {
      final url =
          await ref.read(expensesRepoProvider).receiptSignedUrl(e.receiptUrl!);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open receipt: $err')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '${Formatters.naira(e.amountNgn)} · ${e.category}'
            '${e.payee != null ? ' · ${e.payee}' : ''} will be removed.'),
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
      final repo = ref.read(expensesRepoProvider);
      if (e.hasReceipt) {
        try {
          await repo.deleteReceipt(e.receiptUrl!);
        } catch (_) {}
      }
      await repo.delete(e.id);
      ref.invalidate(expensesProvider);
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
    final async = ref.watch(expensesProvider);
    final addBtn = FilledButton.icon(
      onPressed: () => _openEditor(context, ref, null),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add expense'),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                child: Text('Failed to load expenses: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (expenses) {
                if (expenses.isEmpty) return _empty(context, ref);
                final total =
                    expenses.fold<num>(0, (s, e) => s + e.amountNgn);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${expenses.length} expense${expenses.length == 1 ? '' : 's'} · '
                        '${Formatters.naira(total)} total',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ExpenseRow(
                          expense: expenses[i],
                          onEdit: () => _openEditor(context, ref, expenses[i]),
                          onDelete: () =>
                              _confirmDelete(context, ref, expenses[i]),
                          onViewReceipt: expenses[i].hasReceipt
                              ? () => _viewReceipt(context, ref, expenses[i])
                              : null,
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
          const Icon(Icons.receipt_long_outlined,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No expenses logged yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Track rent, salaries, marketing and more to see your P&L.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context, ref, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add expense'),
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
        Text('Expenses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('Money going out — rent, salaries, marketing, fees and more.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onViewReceipt;

  const _ExpenseRow({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
    this.onViewReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final e = expense;
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
                        child: Text(e.category,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (e.payee != null && e.payee!.isNotEmpty) ...[
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.muted)),
                        Flexible(
                          child: Text(e.payee!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.text),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.date(e.spentOn) +
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
                    color: AppColors.text)),
            if (onViewReceipt != null)
              IconButton(
                icon: const Icon(Icons.receipt_long, size: 18),
                tooltip: 'View receipt',
                color: AppColors.brand,
                visualDensity: VisualDensity.compact,
                onPressed: onViewReceipt,
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
      ),
    );
  }
}

class _ExpenseEditorDialog extends ConsumerStatefulWidget {
  final Expense? existing;
  const _ExpenseEditorDialog({this.existing});

  @override
  ConsumerState<_ExpenseEditorDialog> createState() =>
      _ExpenseEditorDialogState();
}

class _ExpenseEditorDialogState
    extends ConsumerState<_ExpenseEditorDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _payee;
  late final TextEditingController _notes;
  late String _category;
  late DateTime _spentOn;

  // Receipt state
  String? _existingReceiptPath;
  PickedFile? _pickedReceipt;
  bool _removeReceipt = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e != null ? e.amountNgn.toString() : '');
    _payee = TextEditingController(text: e?.payee ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? kExpenseCategories.first;
    _spentOn = e?.spentOn ?? DateTime.now();
    _existingReceiptPath = e?.receiptUrl;
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
      initialDate: _spentOn,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _spentOn = picked);
  }

  Future<void> _viewExistingReceipt() async {
    if (_existingReceiptPath == null) return;
    try {
      final url = await ref
          .read(expensesRepoProvider)
          .receiptSignedUrl(_existingReceiptPath!);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open receipt: $e')),
        );
      }
    }
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
      final repo = ref.read(expensesRepoProvider);

      // Upload a freshly-picked receipt first (if any).
      String? uploadedPath;
      if (_pickedReceipt != null) {
        uploadedPath = await repo.uploadReceipt(
          bytes: _pickedReceipt!.bytes,
          filename: _pickedReceipt!.filename,
        );
      }

      if (widget.existing == null) {
        await repo.create(
          category: _category,
          amountNgn: amount,
          spentOn: _spentOn,
          payee: _payee.text,
          notes: _notes.text,
          receiptUrl: uploadedPath,
        );
      } else {
        if (_pickedReceipt != null) {
          // Replaced the receipt — drop the old file, save the new path.
          if (_existingReceiptPath != null) {
            try {
              await repo.deleteReceipt(_existingReceiptPath!);
            } catch (_) {}
          }
          await repo.update(
            widget.existing!.id,
            category: _category,
            amountNgn: amount,
            spentOn: _spentOn,
            payee: _payee.text,
            notes: _notes.text,
            receiptUrl: uploadedPath,
          );
        } else if (_removeReceipt) {
          if (_existingReceiptPath != null) {
            try {
              await repo.deleteReceipt(_existingReceiptPath!);
            } catch (_) {}
          }
          await repo.update(
            widget.existing!.id,
            category: _category,
            amountNgn: amount,
            spentOn: _spentOn,
            payee: _payee.text,
            notes: _notes.text,
            clearReceipt: true,
          );
        } else {
          await repo.update(
            widget.existing!.id,
            category: _category,
            amountNgn: amount,
            spentOn: _spentOn,
            payee: _payee.text,
            notes: _notes.text,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildReceiptField() {
    final hasExisting = _existingReceiptPath != null &&
        !_removeReceipt &&
        _pickedReceipt == null;
    if (hasExisting) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.brandLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brand, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file, size: 18, color: AppColors.brand),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Receipt attached', style: TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: _viewExistingReceipt,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('View', style: TextStyle(fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _removeReceipt = true),
            ),
          ],
        ),
      );
    }
    return SingleFilePicker(
      label: 'Attach receipt (image or PDF)',
      onChanged: (f) => setState(() {
        _pickedReceipt = f;
        if (f != null) _removeReceipt = false;
      }),
    );
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
              child: Text(editing ? 'Edit expense' : 'Add expense',
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
                    _label('Date *'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(6),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(Formatters.date(_spentOn),
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Payee'),
                    TextField(
                      controller: _payee,
                      decoration: const InputDecoration(
                        hintText: 'Who was paid (optional)',
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
                    const SizedBox(height: 14),
                    _label('Receipt'),
                    _buildReceiptField(),
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
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
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
                        : (editing ? 'Save' : 'Add expense')),
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
