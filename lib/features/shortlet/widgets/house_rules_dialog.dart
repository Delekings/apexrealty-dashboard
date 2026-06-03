// lib/features/shortlet/widgets/house_rules_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/bookings_repository.dart';

class HouseRulesDialog extends ConsumerStatefulWidget {
  final BookingOverview booking;
  const HouseRulesDialog({super.key, required this.booking});

  @override
  ConsumerState<HouseRulesDialog> createState() => _HouseRulesDialogState();
}

class _HouseRulesDialogState extends ConsumerState<HouseRulesDialog> {
  final _typedName = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _typedName.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final typed = _typedName.text.trim();
    if (typed.isEmpty) {
      setState(() => _error = 'Type the guest name to confirm');
      return;
    }
    if (typed.toLowerCase() !=
        widget.booking.clientName.trim().toLowerCase()) {
      setState(() =>
      _error = 'Typed name doesn\'t match the guest on this booking');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Store the typed name as a "signature" string (legal attestation)
      await ref.read(bookingsRepoProvider).acceptHouseRules(
        id: widget.booking.id,
        signatureUrl: 'typed:$typed',
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
    final alreadyAccepted = widget.booking.houseRulesAcceptedAt != null;
    final rules = widget.booking.houseRulesMarkdown ?? '';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('House rules & terms',
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
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rules.isEmpty)
                      const Text(
                        'No house rules set for this listing. Edit the rental listing to add them.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontStyle: FontStyle.italic),
                      )
                    else
                      Text(rules,
                          style: const TextStyle(
                              fontSize: 13, height: 1.5)),
                    const SizedBox(height: 20),
                    if (alreadyAccepted)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.brand),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Accepted',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brand)),
                                  Text(
                                    'By ${widget.booking.clientName} · ${widget.booking.houseRulesAcceptedAt}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.brand),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (rules.isNotEmpty) ...[
                      const Text(
                        'To accept these rules on the guest\'s behalf, type their full name as it appears on the booking.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _typedName,
                        decoration: InputDecoration(
                          labelText: 'Guest name',
                          hintText: widget.booking.clientName,
                          isDense: true,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.danger)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                    _saving ? null : () => Navigator.pop(context),
                    child: Text(alreadyAccepted ? 'Close' : 'Cancel'),
                  ),
                  if (!alreadyAccepted && rules.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _saving ? null : _accept,
                      icon: _saving
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 14),
                      label:
                      Text(_saving ? 'Saving…' : 'Mark as accepted'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}