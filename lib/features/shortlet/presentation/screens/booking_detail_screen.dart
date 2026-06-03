// lib/features/shortlet/presentation/screens/booking_detail_screen.dart
//
// Single-booking deep view. Shows guest, stay, pricing, house rules,
// payments, notes, and activity. All status & money actions live here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/bookings_repository.dart';
import '../../widgets/cancel_booking_dialog.dart';
import '../../widgets/house_rules_dialog.dart';
import '../../widgets/record_booking_payment_dialog.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  void _refresh(WidgetRef ref) {
    ref.invalidate(bookingDetailProvider(bookingId));
    ref.invalidate(bookingPaymentsProvider(bookingId));
    ref.invalidate(upcomingBookingsProvider);
    ref.invalidate(inHouseBookingsProvider);
    ref.invalidate(pastBookingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingDetailProvider(bookingId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(
          child: Text('Could not load booking: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Booking not found.'));
          }
          return _DetailBody(booking: booking, onChanged: () => _refresh(ref));
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final BookingOverview booking;
  final VoidCallback onChanged;
  const _DetailBody({required this.booking, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('d MMM yyyy');
    final dateTimeFmt = DateFormat('d MMM yyyy · h:mm a');
    final wide = MediaQuery.of(context).size.width >= 1000;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: () => context.go('/bookings'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(booking.bookingNo,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        _statusPill(booking.status),
                        const SizedBox(width: 6),
                        _paymentPill(booking.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(booking.clientName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.propertyTitle}${booking.unitTitle != null ? ' · ${booking.unitTitle}' : ''} · ${booking.propertyLocation}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFmt.format(booking.checkInDate)} → ${dateFmt.format(booking.checkOutDate)} · ${booking.nights} night${booking.nights == 1 ? '' : 's'} · ${booking.guestsCount} guest${booking.guestsCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusActions(context, ref),
            ],
          ),
          const SizedBox(height: 20),

          // 3-column info grid
          wide
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _guestCard()),
              const SizedBox(width: 12),
              Expanded(child: _stayCard(dateTimeFmt)),
              const SizedBox(width: 12),
              Expanded(child: _pricingCard(context, ref)),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _guestCard(),
              const SizedBox(height: 12),
              _stayCard(dateTimeFmt),
              const SizedBox(height: 12),
              _pricingCard(context, ref),
            ],
          ),
          const SizedBox(height: 16),

          // House rules
          _houseRulesCard(context, ref, dateTimeFmt),
          const SizedBox(height: 12),

          // Payments
          _paymentsCard(context, ref, dateTimeFmt),
          const SizedBox(height: 12),

          // Notes
          _notesCard(context, ref),
          const SizedBox(height: 12),

          // Cancellation info if cancelled
          if (booking.status == BookingStatus.cancelled)
            _cancellationCard(dateTimeFmt),
        ],
      ),
    );
  }

  Widget _statusActions(BuildContext context, WidgetRef ref) {
    final s = booking.status;
    if (s == BookingStatus.cancelled ||
        s == BookingStatus.checkedOut ||
        s == BookingStatus.noShow) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s == BookingStatus.pending)
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Confirm'),
            onPressed: () => _setStatus(ref, BookingStatus.confirmed),
          ),
        if (s == BookingStatus.confirmed)
          FilledButton.icon(
            icon: const Icon(Icons.login, size: 14),
            label: const Text('Check in'),
            onPressed: () => _setStatus(ref, BookingStatus.checkedIn),
          ),
        if (s == BookingStatus.checkedIn)
          FilledButton.icon(
            icon: const Icon(Icons.logout, size: 14),
            label: const Text('Check out'),
            onPressed: () => _setStatus(ref, BookingStatus.checkedOut),
          ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined,
              size: 14, color: AppColors.danger),
          label: const Text('Cancel',
              style: TextStyle(color: AppColors.danger)),
          onPressed: () => _openCancelDialog(context),
        ),
      ],
    );
  }

  Future<void> _setStatus(WidgetRef ref, BookingStatus s) async {
    await ref.read(bookingsRepoProvider).updateStatus(booking.id, s);
    onChanged();
  }

  Future<void> _openCancelDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => CancelBookingDialog(
          bookingId: booking.id, bookingNo: booking.bookingNo),
    );
    if (ok == true) onChanged();
  }

  Widget _guestCard() => _infoCard(
    title: 'GUEST',
    children: [
      _line(Icons.person, booking.clientName, bold: true),
      _line(Icons.phone, booking.clientPhone),
      if (booking.clientEmail != null)
        _line(Icons.email, booking.clientEmail!),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 12),
        label: const Text('View profile'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => null, // hook up later
      ),
    ],
  );

  Widget _stayCard(DateFormat dateTimeFmt) => _infoCard(
    title: 'STAY',
    children: [
      _line(Icons.login, 'Check-in ${booking.checkInTime}'),
      _line(Icons.logout, 'Check-out ${booking.checkOutTime}'),
      _line(Icons.people, '${booking.guestsCount} guest${booking.guestsCount == 1 ? '' : 's'}'),
      _line(Icons.source, 'Source: ${bookingSourceLabel(booking.source)}'),
      if (booking.agentName != null)
        _line(Icons.badge, 'Handled by ${booking.agentName!}'),
      if (booking.checkedInAt != null)
        _line(Icons.access_time,
            'Arrived ${dateTimeFmt.format(booking.checkedInAt!)}'),
      if (booking.checkedOutAt != null)
        _line(Icons.access_time,
            'Departed ${dateTimeFmt.format(booking.checkedOutAt!)}'),
    ],
  );

  Widget _pricingCard(BuildContext context, WidgetRef ref) {
    final subtotal = booking.nightlyRateNgn * booking.nights;
    return _infoCard(
      title: 'PRICING',
      children: [
        _moneyRow(
          '${Formatters.naira(booking.nightlyRateNgn)} × ${booking.nights} night${booking.nights == 1 ? '' : 's'}',
          Formatters.naira(subtotal),
        ),
        if (booking.cleaningFeeNgn > 0)
          _moneyRow(
              'Cleaning', Formatters.naira(booking.cleaningFeeNgn)),
        if (booking.securityDepositNgn > 0)
          _moneyRow('Deposit', Formatters.naira(booking.securityDepositNgn)),
        const Divider(height: 14),
        _moneyRow('Total', Formatters.naira(booking.totalNgn), bold: true),
        _moneyRow('Paid', Formatters.naira(booking.amountPaidNgn),
            color: AppColors.brand),
        _moneyRow('Balance', Formatters.naira(booking.balanceNgn),
            color: booking.balanceNgn > 0
                ? AppColors.danger
                : AppColors.brand),
        if (booking.balanceNgn > 0 &&
            booking.status != BookingStatus.cancelled) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.payments, size: 14),
              label: const Text('Record payment'),
              onPressed: () => _openPaymentDialog(context),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openPaymentDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => RecordBookingPaymentDialog(booking: booking),
    );
    if (ok == true) onChanged();
  }

  Widget _houseRulesCard(
      BuildContext context, WidgetRef ref, DateFormat dateTimeFmt) {
    final accepted = booking.houseRulesAcceptedAt != null;
    final hasRules = (booking.houseRulesMarkdown ?? '').trim().isNotEmpty;
    return _infoCard(
      title: 'HOUSE RULES',
      trailing: TextButton.icon(
        icon: const Icon(Icons.menu_book, size: 14),
        label: Text(hasRules ? 'View / accept' : 'View'),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => HouseRulesDialog(booking: booking),
          );
          if (ok == true) onChanged();
        },
      ),
      children: [
        if (!hasRules)
          const Text(
            'No house rules configured for this listing. Edit the rental listing to add them.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontStyle: FontStyle.italic),
          )
        else if (accepted)
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accepted by ${booking.clientName} · ${dateTimeFmt.format(booking.houseRulesAcceptedAt!)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.brand),
                ),
              ),
            ],
          )
        else
          Row(
            children: const [
              Icon(Icons.error_outline, size: 16, color: AppColors.warn),
              SizedBox(width: 8),
              Text(
                'Guest has not yet accepted the house rules',
                style: TextStyle(fontSize: 12, color: AppColors.warn),
              ),
            ],
          ),
      ],
    );
  }

  Widget _paymentsCard(
      BuildContext context, WidgetRef ref, DateFormat dateTimeFmt) {
    final paymentsAsync = ref.watch(bookingPaymentsProvider(booking.id));
    return _infoCard(
      title: 'PAYMENTS',
      children: [
        paymentsAsync.when(
          loading: () => const SizedBox(
              height: 24,
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand)))),
          error: (e, _) => Text('Could not load payments: $e',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.danger)),
          data: (payments) {
            if (payments.isEmpty) {
              return const Text(
                'No payments recorded yet.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic),
              );
            }
            return Column(
              children: [
                for (final p in payments) ...[
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 14, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(Formatters.naira(p.amountNgn),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '${p.channel} · ${dateTimeFmt.format(p.paidAt)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted),
                            ),
                            if (p.reference != null)
                              Text('Ref: ${p.reference}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p != payments.last) const Divider(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _notesCard(BuildContext context, WidgetRef ref) {
    return _infoCard(
      title: 'NOTES',
      trailing: TextButton.icon(
        icon: const Icon(Icons.edit, size: 12),
        label: const Text('Edit'),
        onPressed: () => _openEditNotes(context, ref),
      ),
      children: [
        Text(
          (booking.notes ?? '').isEmpty
              ? 'No notes yet.'
              : booking.notes!,
          style: TextStyle(
            fontSize: 12,
            color: (booking.notes ?? '').isEmpty
                ? AppColors.muted
                : AppColors.text,
            fontStyle: (booking.notes ?? '').isEmpty
                ? FontStyle.italic
                : FontStyle.normal,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _openEditNotes(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: booking.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit notes'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Arriving late, airport pickup, special diet...',
              isDense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(bookingsRepoProvider)
          .updateNotes(booking.id, ctrl.text);
      onChanged();
    }
  }

  Widget _cancellationCard(DateFormat dateTimeFmt) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.dangerLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CANCELLED',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        if (booking.cancelledAt != null)
          Text(
            'Cancelled on ${dateTimeFmt.format(booking.cancelledAt!)}',
            style:
            const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        if (booking.cancellationReason != null) ...[
          const SizedBox(height: 4),
          Text(
            'Reason: ${booking.cancellationReason}',
            style:
            const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ],
      ],
    ),
  );

  // -------------- Helpers --------------

  Widget _infoCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.5)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: bold ? 13 : 12,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: color ?? AppColors.text)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 13 : 12,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: color ?? AppColors.text)),
        ],
      ),
    );
  }

  Widget _statusPill(BookingStatus s) {
    final color = switch (s) {
      BookingStatus.pending => AppColors.warn,
      BookingStatus.confirmed => AppColors.brand,
      BookingStatus.checkedIn => AppColors.info,
      BookingStatus.checkedOut => AppColors.muted,
      BookingStatus.cancelled => AppColors.danger,
      BookingStatus.noShow => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(bookingStatusLabel(s),
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _paymentPill(BookingPaymentStatus s) {
    final color = switch (s) {
      BookingPaymentStatus.paid => AppColors.brand,
      BookingPaymentStatus.partial => AppColors.warn,
      BookingPaymentStatus.refunded => AppColors.muted,
      BookingPaymentStatus.unpaid => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(bookingPaymentStatusLabel(s),
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}