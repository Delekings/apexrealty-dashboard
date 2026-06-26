// lib/features/shortlet/widgets/record_booking_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/bookings_repository.dart';

class RecordBookingPaymentDialog extends ConsumerStatefulWidget {
  final BookingOverview booking;
  const RecordBookingPaymentDialog({super.key, required this.booking});

  @override
  ConsumerState<RecordBookingPaymentDialog> createState() =>
      _RecordBookingPaymentDialogState();
}

class _RecordBookingPaymentDialogState
    extends ConsumerState<RecordBookingPaymentDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  PaymentChannel _channel = PaymentChannel.bankTransfer;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to remaining balance
    _amount.text = widget.booking.balanceNgn.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = num.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amt > widget.booking.balanceNgn) {
      setState(() =>
      _error = 'Amount exceeds outstanding balance of ${Formatters.naira(widget.booking.balanceNgn)}');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(bookingsRepoProvider).recordPayment(
        bookingId: widget.booking.id,
        amount: amt,
        channel: paymentChannelToDb(_channel),
        reference: _reference.text,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Record payment',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed:
                    _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Outstanding balance: ${Formatters.naira(widget.booking.balanceNgn)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '₦ ',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentChannel>(
                isExpanded: true,
                value: _channel,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Channel *',
                  isDense: true,
                ),
                items: PaymentChannel.values
                    .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(paymentChannelLabel(c),
                      style: const TextStyle(fontSize: 13)),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _channel = v ?? _channel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                  hintText: 'Bank transaction ref, Paystack ID, etc',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
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
                        : const Icon(Icons.check, size: 14),
                    label: Text(_saving ? 'Recording…' : 'Record payment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}