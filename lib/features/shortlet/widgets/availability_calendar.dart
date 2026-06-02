// lib/features/shortlet/widgets/availability_calendar.dart
//
// Month-view calendar that fetches booked ranges for a rental listing
// and lets the operator pick a [check_in, check_out) range. Booked nights
// are visually marked and not tappable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/bookings_repository.dart';

class AvailabilityCalendar extends ConsumerStatefulWidget {
  final String propertyId;
  final String? propertyUnitTypeId;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final void Function(DateTime? checkIn, DateTime? checkOut) onRangeChanged;

  const AvailabilityCalendar({
    super.key,
    required this.propertyId,
    required this.propertyUnitTypeId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.onRangeChanged,
  });

  @override
  ConsumerState<AvailabilityCalendar> createState() =>
      _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends ConsumerState<AvailabilityCalendar> {
  DateTime _visibleMonth =
  DateTime(DateTime.now().year, DateTime.now().month);

  List<BookedRange> _bookedRanges = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRanges();
  }

  @override
  void didUpdateWidget(AvailabilityCalendar old) {
    super.didUpdateWidget(old);
    if (old.propertyId != widget.propertyId ||
        old.propertyUnitTypeId != widget.propertyUnitTypeId) {
      _loadRanges();
    }
  }

  Future<void> _loadRanges() async {
    setState(() => _loading = true);
    try {
      final ranges =
      await ref.read(bookingsRepoProvider).getBookedRanges(
        propertyId: widget.propertyId,
        propertyUnitTypeId: widget.propertyUnitTypeId,
        from: DateTime.now().subtract(const Duration(days: 7)),
        to: DateTime.now().add(const Duration(days: 365)),
      );
      if (mounted) setState(() => _bookedRanges = ranges);
    } catch (_) {
      // silently ignore — calendar still works without booked overlay
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isBooked(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final r in _bookedRanges) {
      final start = DateTime(
          r.checkInDate.year, r.checkInDate.month, r.checkInDate.day);
      final end = DateTime(
          r.checkOutDate.year, r.checkOutDate.month, r.checkOutDate.day);
      // [start, end) — checkout day is free
      if (!d.isBefore(start) && d.isBefore(end)) return true;
    }
    return false;
  }

  bool _rangeHasConflict(DateTime from, DateTime to) {
    for (DateTime d = from;
    d.isBefore(to);
    d = d.add(const Duration(days: 1))) {
      if (_isBooked(d)) return true;
    }
    return false;
  }

  void _onDayTap(DateTime day) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (day.isBefore(today)) return;
    if (_isBooked(day)) return;

    final checkIn = widget.checkInDate;
    final checkOut = widget.checkOutDate;

    // No check-in yet → set it
    if (checkIn == null) {
      widget.onRangeChanged(day, null);
      return;
    }

    // Already have a full range → start over
    if (checkOut != null) {
      widget.onRangeChanged(day, null);
      return;
    }

    // Have check-in only → set check-out
    if (day.isAtSameMomentAs(checkIn) || day.isBefore(checkIn)) {
      widget.onRangeChanged(day, null);
      return;
    }

    // Check for conflicts in the proposed range
    if (_rangeHasConflict(checkIn, day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Those dates overlap an existing booking. Pick a clear range.'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onRangeChanged(day, null);
      return;
    }

    widget.onRangeChanged(checkIn, day);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _monthHeader(),
          const SizedBox(height: 8),
          _weekdayHeader(),
          const SizedBox(height: 4),
          _monthGrid(),
          const SizedBox(height: 10),
          _legend(),
        ],
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: () => setState(() {
            _visibleMonth = DateTime(
                _visibleMonth.year, _visibleMonth.month - 1);
          }),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy').format(_visibleMonth),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.brand),
          ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: () => setState(() {
            _visibleMonth = DateTime(
                _visibleMonth.year, _visibleMonth.month + 1);
          }),
        ),
      ],
    );
  }

  Widget _weekdayHeader() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(l,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid() {
    final firstOfMonth =
    DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    // weekday: 1=Mon..7=Sun → leading blank slots
    final leading = firstOfMonth.weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                Expanded(child: _dayCell(r * 7 + c - leading + 1)),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(int dayNum) {
    final firstOfMonth =
    DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 40);
    }

    final day = DateTime(firstOfMonth.year, firstOfMonth.month, dayNum);
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPast = day.isBefore(today);
    final isBooked = _isBooked(day);

    final ci = widget.checkInDate;
    final co = widget.checkOutDate;
    final isCheckIn = ci != null && _sameDay(ci, day);
    final isCheckOut = co != null && _sameDay(co, day);
    final isInRange = ci != null &&
        co != null &&
        day.isAfter(ci) &&
        day.isBefore(co);

    Color? bg;
    Color text = AppColors.text;
    if (isPast) {
      text = AppColors.muted.withOpacity(0.5);
    } else if (isBooked) {
      bg = AppColors.bg2;
      text = AppColors.muted.withOpacity(0.6);
    } else if (isCheckIn || isCheckOut) {
      bg = AppColors.brand;
      text = Colors.white;
    } else if (isInRange) {
      bg = AppColors.brandLight;
      text = AppColors.brand;
    }

    final tappable = !isPast && !isBooked;

    return InkWell(
      onTap: tappable ? () => _onDayTap(day) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  color: text,
                  fontWeight: (isCheckIn || isCheckOut)
                      ? FontWeight.w600
                      : FontWeight.w400,
                  decoration: isBooked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            if (_sameDay(day, today) && bg == null)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        _legendDot(AppColors.brand, 'Selected'),
        const SizedBox(width: 12),
        _legendDot(AppColors.brandLight, 'In range'),
        const SizedBox(width: 12),
        _legendDot(AppColors.bg2, 'Booked'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
            const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}