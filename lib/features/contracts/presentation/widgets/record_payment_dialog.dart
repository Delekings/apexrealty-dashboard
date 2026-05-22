// lib/features/contracts/presentation/widgets/record_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/single_file_picker.dart';
import '../../../../data/models/models.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/contracts_providers.dart';

/// Modal for recording a manual payment against a specific installment.
class RecordPaymentDialog extends ConsumerStatefulWidget {
  final String contractId;
  final Installment installment;
  final String installmentLabel; // e.g. "Installment 3 of 12"

  const RecordPaymentDialog({
    super.key,
    required this.contractId,
    required this.installment,
    required this.installmentLabel,
  });

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  PaymentChannel _channel = PaymentChannel.bankTransfer;
  DateTime _paidAt = DateTime.now();
  PickedFile? _receipt;

  bool _submitting = false;
  String? _error;

  // Success state
  bool _success = false;
  num? _savedAmount;
  String? _savedReceiptNo;
  String? _savedReceiptPath;
  bool _downloadingReceipt = false;
  String? _receiptError;

  @override
  void initState() {
    super.initState();
    final balance = widget.installment.balance;
    _amount = TextEditingController(
      text: NumberFormat('#,###').format(balance),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  num? get _parsedAmount =>
      num.tryParse(_amount.text.replaceAll(',', ''));

  bool get _isValid {
    final a = _parsedAmount;
    if (a == null || a <= 0) return false;
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on your profile');
      }

      final repo = ref.read(contractsRepoProvider);

      // 1. Record the payment — returns the new payment_id
      final paymentId = await repo.recordManualPayment(
        agencyId: profile!.agencyId!,
        contractId: widget.contractId,
        installmentId: widget.installment.id,
        amount: _parsedAmount!,
        channel: _channel,
        paidAt: _paidAt,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        receiptBytes: _receipt?.bytes,
        receiptFilename: _receipt?.filename,
      );

      // 2. Auto-generate the receipt PDF (non-fatal — payment is already saved)
      String? receiptPath;
      String? receiptNo;
      try {
        final result = await repo.generateAndUploadReceipt(
          paymentId: paymentId,
          agencyId: profile.agencyId!,
        );
        receiptPath = result.path;
        receiptNo = result.receiptNo;
      } catch (e) {
        // Log but don't fail — receipt can be regenerated later
        debugPrint('Receipt generation failed: $e');
        setState(() => _receiptError =
        'Payment saved but receipt couldn\'t be generated. '
            'You can regenerate it from the payment history.');
      }

      // 3. Refresh the contract detail
      ref.invalidate(contractDetailProvider(widget.contractId));

      // 4. Show success state inside this dialog
      if (mounted) {
        setState(() {
          _success = true;
          _savedAmount = _parsedAmount;
          _savedReceiptPath = receiptPath;
          _savedReceiptNo = receiptNo;
        });
      }
    } catch (e) {
      setState(() => _error =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _downloadReceipt() async {
    if (_savedReceiptPath == null) return;
    setState(() => _downloadingReceipt = true);
    try {
      final url = await ref
          .read(contractsRepoProvider)
          .receiptUrl(_savedReceiptPath!);
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _receiptError = e
          .toString()
          .replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _downloadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: _success ? _successContent() : _formContent(),
          ),
        ),
      ),
    );
  }

  // ---------- SUCCESS STATE ----------

  Widget _successContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top icon + close
        Row(
          children: [
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.brandLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check,
                size: 30, color: AppColors.brand),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Payment recorded',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${Formatters.naira(_savedAmount!)} received',
            style:
            const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 18),

        // Receipt card
        if (_savedReceiptPath != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long,
                      size: 18, color: AppColors.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Receipt ready',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      if (_savedReceiptNo != null)
                        Text(_savedReceiptNo!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                fontFamily: 'monospace')),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _downloadingReceipt
                      ? null
                      : _downloadReceipt,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _downloadingReceipt
                      ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Icon(Icons.download, size: 14),
                  label: Text(_downloadingReceipt
                      ? 'Opening…'
                      : 'Download'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You can re-download this receipt anytime from the '
                'payment history on the contract.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _receiptError ??
                        'Payment saved. Receipt will be generated on next view.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warn),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- FORM STATE ----------

  Widget _formContent() {
    final inst = widget.installment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record payment',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(widget.installmentLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Installment summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _kv('Due', Formatters.date(inst.dueDate)),
              _kv('Total this installment',
                  Formatters.naira(inst.amount)),
              _kv('Already paid',
                  Formatters.naira(inst.amountPaid)),
              _kv('Balance', Formatters.naira(inst.balance),
                  emphasize: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _label('Amount received (₦) *'),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
            _NumberFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'e.g. 500,000',
            isDense: true,
          ),
        ),
        if (_parsedAmount != null &&
            _parsedAmount! < inst.balance) ...[
          const SizedBox(height: 6),
          Text(
            'This is a partial payment. Remaining balance after this: '
                '${Formatters.naira(inst.balance - _parsedAmount!)}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.warn),
          ),
        ],
        const SizedBox(height: 12),

        _label('Payment channel *'),
        _channelPicker(),
        const SizedBox(height: 12),

        _twoCol(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Date received *'),
              _dateField(),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Reference number'),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  hintText: 'Bank ref / cheque no.',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _label('Proof of payment (optional)'),
        const SizedBox(height: 4),
        SingleFilePicker(
          label: 'Upload screenshot or PDF',
          onChanged: (f) => setState(() => _receipt = f),
        ),
        const SizedBox(height: 12),

        _label('Notes'),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Anything noteworthy about this payment',
            isDense: true,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: (_isValid && !_submitting) ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
                  : const Icon(Icons.check, size: 16),
              label: Text(_submitting
                  ? 'Saving & generating receipt…'
                  : 'Record payment'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _channelPicker() {
    final options = [
      (PaymentChannel.bankTransfer, 'Bank transfer', Icons.account_balance),
      (PaymentChannel.cash, 'Cash', Icons.payments_outlined),
      (PaymentChannel.cheque, 'Cheque', Icons.receipt_long_outlined),
      (PaymentChannel.ussd, 'USSD', Icons.dialpad),
      (PaymentChannel.card, 'Card', Icons.credit_card),
      (PaymentChannel.other, 'Other', Icons.more_horiz),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (ch, label, icon) in options)
          GestureDetector(
            onTap: () => setState(() => _channel = ch),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _channel == ch
                    ? AppColors.brandLight
                    : AppColors.bg,
                border: Border.all(
                  color: _channel == ch
                      ? AppColors.brand
                      : AppColors.border,
                  width: _channel == ch ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color: _channel == ch
                          ? AppColors.brand
                          : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: _channel == ch
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: _channel == ch
                              ? AppColors.brand
                              : AppColors.text)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(Formatters.date(_paidAt),
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _kv(String k, String v, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted)),
          ),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  color: emphasize ? AppColors.brand : AppColors.text)),
        ],
      ),
    );
  }
}

class _NumberFormatter extends TextInputFormatter {
  static final _f = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _f.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}