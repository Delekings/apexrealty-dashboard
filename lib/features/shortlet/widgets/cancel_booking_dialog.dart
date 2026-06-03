// lib/features/shortlet/widgets/cancel_booking_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/bookings_repository.dart';

class CancelBookingDialog extends ConsumerStatefulWidget {
  final String bookingId;
  final String bookingNo;
  const CancelBookingDialog({
    super.key,
    required this.bookingId,
    required this.bookingNo,
  });

  @override
  ConsumerState<CancelBookingDialog> createState() =>
      _CancelBookingDialogState();
}

class _CancelBookingDialogState
    extends ConsumerState<CancelBookingDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Reason is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(bookingsRepoProvider).cancel(
        id: widget.bookingId,
        reason: reason,
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
    return AlertDialog(
      title: Text('Cancel ${widget.bookingNo}?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This frees up the dates so others can book this unit. Cancellation cannot be undone.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'Guest changed plans, payment failed, etc.',
                isDense: true,
              ),
              autofocus: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Keep booking'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Cancelling…' : 'Cancel booking'),
        ),
      ],
    );
  }
}