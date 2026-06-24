// lib/features/shortlet/presentation/screens/bookings_screen.dart
//
// The operator's home for shortlet ops. Three tabs: upcoming,
// in-house, past. Each shows bookings with quick status actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/bookings_repository.dart';
import '../../../../data/repositories/rental_listings_repository.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/layout_helpers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(upcomingBookingsProvider);
    ref.invalidate(inHouseBookingsProvider);
    ref.invalidate(pastBookingsProvider);
  }

  Future<void> _handleNewBooking() async {
    final listings = await ref.read(allActiveListingsProvider.future);
    if (!mounted) return;

    if (listings.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No rental listings yet'),
          content: const Text(
            'You need at least one active rental listing before you can create a booking. Open any property and click "Set up rental listing".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/properties');
              },
              child: const Text('Go to Properties'),
            ),
          ],
        ),
      );
      return;
    }

    // C3 will live at /bookings/new — placeholder for now
    if (mounted) context.go('/bookings/new');
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingBookingsProvider);
    final inHouse = ref.watch(inHouseBookingsProvider);
    final past = ref.watch(pastBookingsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bookings',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      'Manage check-ins, check-outs, and reservations.',
                      style:
                      TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New booking'),
                onPressed: _handleNewBooking,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats strip
          ResponsiveGrid(
            spacing: 12,
            runSpacing: 12,
            mobileColumns: 3,
            tabletColumns: 3,
            desktopColumns: 3,
            children: [
              _statCard(
                label: 'Upcoming',
                value: upcoming.valueOrNull?.length.toString() ?? '–',
                icon: Icons.event_outlined,
                color: AppColors.brand,
              ),
              _statCard(
                label: 'In-house now',
                value: inHouse.valueOrNull?.length.toString() ?? '–',
                icon: Icons.king_bed_outlined,
                color: AppColors.info,
              ),
              _statCard(
                label: 'Past 30 days',
                value: past.valueOrNull?.length.toString() ?? '–',
                icon: Icons.history,
                color: AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.brand,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'In-house'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _bookingsList(
                  upcoming,
                  emptyTitle: 'No upcoming bookings',
                  emptyBody:
                  'Confirmed bookings with future check-in dates will show here.',
                ),
                _bookingsList(
                  inHouse,
                  emptyTitle: 'No one in-house right now',
                  emptyBody:
                  'Guests who have checked in but not yet out will appear here.',
                ),
                _bookingsList(
                  past,
                  emptyTitle: 'No past bookings yet',
                  emptyBody:
                  'Completed, cancelled, and no-show bookings from the last 30 days will appear here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style:
            const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _bookingsList(
      AsyncValue<List<BookingOverview>> async, {
        required String emptyTitle,
        required String emptyBody,
      }) {
    return async.when(
      loading: () => const Center(
          child: LintelLoader()),
      error: (e, _) => Center(
        child: Text('Could not load bookings: $e',
            style: const TextStyle(color: AppColors.danger)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(emptyTitle, emptyBody);
        }
        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async => _refreshAll(),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _BookingRow(
              booking: items[i],
              onChanged: _refreshAll,
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(String title, String body) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingRow extends ConsumerWidget {
  final BookingOverview booking;
  final VoidCallback onChanged;

  const _BookingRow({required this.booking, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('d MMM');
    final today = DateTime.now();
    final isArrivingToday = booking.status == BookingStatus.confirmed &&
        _isSameDay(booking.checkInDate, today);
    final isDepartingToday = booking.status == BookingStatus.checkedIn &&
        _isSameDay(booking.checkOutDate, today);

    final statusBox = SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusPill(booking.status),
          if (isArrivingToday) ...[
            const SizedBox(height: 4),
            _smallTag('Arriving today', AppColors.brand),
          ],
          if (isDepartingToday) ...[
            const SizedBox(height: 4),
            _smallTag('Departing today', AppColors.warn),
          ],
        ],
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Booking ref + stay dates. Wrap so the date string flows to a
        // second line on narrow screens instead of overflowing horizontally.
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              booking.bookingNo,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              '${dateFmt.format(booking.checkInDate)} → ${dateFmt.format(booking.checkOutDate)} · ${booking.nights} night${booking.nights == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          booking.clientName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          booking.unitTitle != null
              ? '${booking.propertyTitle} · ${booking.unitTitle}'
              : booking.propertyTitle,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              Formatters.naira(booking.totalNgn),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '· ${bookingPaymentStatusLabel(booking.paymentStatus)}',
              style: TextStyle(
                  fontSize: 12,
                  color: booking.paymentStatus == BookingPaymentStatus.paid
                      ? AppColors.brand
                      : AppColors.muted),
            ),
          ],
        ),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go('/bookings/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        // On phones the dense three-column row can't fit the action button,
        // so we drop it to a full-width button beneath the details.
        child: context.isMobile
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusBox,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            ),
            const SizedBox(height: 12),
            _rowActions(context, ref, fullWidth: true),
          ],
        )
            : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statusBox,
            const SizedBox(width: 12),
            Expanded(child: details),
            const SizedBox(width: 12),
            _rowActions(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(BuildContext context, WidgetRef ref,
      {bool fullWidth = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
      fullWidth ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        if (booking.status == BookingStatus.confirmed)
          OutlinedButton.icon(
            icon: const Icon(Icons.login, size: 14),
            label: const Text('Check in'),
            onPressed: () => _checkIn(context, ref),
          )
        else if (booking.status == BookingStatus.checkedIn)
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, size: 14),
            label: const Text('Check out'),
            onPressed: () => _checkOut(context, ref),
          )
        else
          TextButton(
            onPressed: () => context.go('/bookings/${booking.id}'),
            child: const Text('View'),
          ),
      ],
    );
  }

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(bookingsRepoProvider)
          .updateStatus(booking.id, BookingStatus.checkedIn);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${booking.clientName} checked in')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    }
  }

  Future<void> _checkOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(bookingsRepoProvider)
          .updateStatus(booking.id, BookingStatus.checkedOut);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${booking.clientName} checked out')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: $e')),
        );
      }
    }
  }

  Widget _statusPill(BookingStatus s) {
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        bookingStatusLabel(s),
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Color _statusColor(BookingStatus s) => switch (s) {
    BookingStatus.pending => AppColors.warn,
    BookingStatus.confirmed => AppColors.brand,
    BookingStatus.checkedIn => AppColors.info,
    BookingStatus.checkedOut => AppColors.muted,
    BookingStatus.cancelled => AppColors.danger,
    BookingStatus.noShow => AppColors.danger,
  };

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}