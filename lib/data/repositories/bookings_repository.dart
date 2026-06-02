// lib/data/repositories/bookings_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class BookingsRepository {
  final SupabaseClient _c = SupabaseService.client;

  // ---------- Reads ----------

  /// All bookings for the current agency, optionally filtered by status.
  Future<List<BookingOverview>> list({
    BookingStatus? status,
    String? propertyId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var q = _c.from('bookings_overview').select();

    if (status != null) {
      q = q.eq('status', bookingStatusToDb(status));
    }
    if (propertyId != null) {
      q = q.eq('property_id', propertyId);
    }
    if (from != null) {
      q = q.gte('check_out_date', from.toIso8601String().split('T').first);
    }
    if (to != null) {
      q = q.lte('check_in_date', to.toIso8601String().split('T').first);
    }

    final rows = await q.order('check_in_date', ascending: true).limit(limit);
    return (rows as List)
        .map((r) => BookingOverview.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Bookings currently active (checked in, not yet checked out)
  Future<List<BookingOverview>> listInHouse() async {
    final rows = await _c
        .from('bookings_overview')
        .select()
        .eq('status', 'checked_in')
        .order('check_out_date');
    return (rows as List)
        .map((r) => BookingOverview.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Upcoming bookings: confirmed + check-in date is today or future
  Future<List<BookingOverview>> listUpcoming() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await _c
        .from('bookings_overview')
        .select()
        .eq('status', 'confirmed')
        .gte('check_in_date', today)
        .order('check_in_date')
        .limit(50);
    return (rows as List)
        .map((r) => BookingOverview.fromMap(r as Map<String, dynamic>))
        .toList();
  }
  /// Past bookings: checked out, cancelled, or no-show. Last 30 days by default.
  Future<List<BookingOverview>> listPast({int daysBack = 30}) async {
    final since = DateTime.now().subtract(Duration(days: daysBack));
    final sinceStr = since.toIso8601String().split('T').first;
    final rows = await _c
        .from('bookings_overview')
        .select()
        .inFilter('status', ['checked_out', 'cancelled', 'no_show'])
        .gte('check_out_date', sinceStr)
        .order('check_out_date', ascending: false)
        .limit(100);
    return (rows as List)
        .map((r) => BookingOverview.fromMap(r as Map<String, dynamic>))
        .toList();
  }
  Future<BookingOverview?> getById(String id) async {
    final row = await _c
        .from('bookings_overview')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : BookingOverview.fromMap(row);
  }

  /// Booked date ranges for a unit, used by the calendar/date picker.
  Future<List<BookedRange>> getBookedRanges({
    required String propertyId,
    String? propertyUnitTypeId,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _c.rpc('get_booked_ranges', params: {
      'p_property_id': propertyId,
      'p_unit_type_id': propertyUnitTypeId,
      if (from != null)
        'p_from': from.toIso8601String().split('T').first,
      if (to != null) 'p_to': to.toIso8601String().split('T').first,
    });
    if (res is! List) return [];
    return res
        .map((r) => BookedRange.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ---------- Writes ----------

  /// Create a new booking. Throws on date overlap (Postgres exclusion
  /// constraint will reject it as code 23P01).
  Future<String> create({
    required String agencyId,
    required String clientId,
    required String propertyId,
    String? propertyUnitTypeId,
    required String rentalListingId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required int guestsCount,
    required num nightlyRateNgn,
    num cleaningFeeNgn = 0,
    num securityDepositNgn = 0,
    String? agentId,
    BookingSource source = BookingSource.direct,
    BookingStatus status = BookingStatus.confirmed,
    String? notes,
  }) async {
    final nights = checkOutDate.difference(checkInDate).inDays;
    if (nights < 1) {
      throw Exception('Check-out must be at least 1 day after check-in');
    }
    final total =
        (nightlyRateNgn * nights) + cleaningFeeNgn + securityDepositNgn;

    final bookingNo = await _c.rpc('next_booking_no', params: {
      'p_agency_id': agencyId,
    }) as String;

    try {
      final res = await _c
          .from('bookings')
          .insert({
        'agency_id': agencyId,
        'booking_no': bookingNo,
        'client_id': clientId,
        'property_id': propertyId,
        if (propertyUnitTypeId != null)
          'property_unit_type_id': propertyUnitTypeId,
        'rental_listing_id': rentalListingId,
        if (agentId != null) 'agent_id': agentId,
        'check_in_date': checkInDate.toIso8601String().split('T').first,
        'check_out_date': checkOutDate.toIso8601String().split('T').first,
        'guests_count': guestsCount,
        'nightly_rate_ngn': nightlyRateNgn,
        'cleaning_fee_ngn': cleaningFeeNgn,
        'security_deposit_ngn': securityDepositNgn,
        'total_ngn': total,
        'status': bookingStatusToDb(status),
        'source': bookingSourceToDb(source),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      })
          .select('id')
          .single();

      final id = res['id'] as String;

      // Log
      try {
        await _c.from('activity_log').insert({
          'agency_id': agencyId,
          'entity_type': 'booking',
          'entity_id': id,
          'action': 'created',
          'description': 'Booking $bookingNo created',
        });
      } catch (_) {/* non-fatal */}

      return id;
    } on PostgrestException catch (e) {
      // 23P01 = exclusion_violation = double-booking
      if (e.code == '23P01') {
        throw Exception(
            'Those dates are already booked for this unit. Pick different dates.');
      }
      rethrow;
    }
  }

  /// Toggle status: confirm, check-in, check-out, no-show
  Future<void> updateStatus(String id, BookingStatus newStatus) async {
    final patch = <String, dynamic>{
      'status': bookingStatusToDb(newStatus),
    };
    if (newStatus == BookingStatus.checkedIn) {
      patch['checked_in_at'] = DateTime.now().toIso8601String();
    } else if (newStatus == BookingStatus.checkedOut) {
      patch['checked_out_at'] = DateTime.now().toIso8601String();
    }
    await _c.from('bookings').update(patch).eq('id', id);
  }

  Future<void> cancel({
    required String id,
    required String reason,
  }) async {
    await _c.from('bookings').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancellation_reason': reason,
    }).eq('id', id);
  }

  /// Mark house rules as accepted (with optional signature image url)
  Future<void> acceptHouseRules({
    required String id,
    String? signatureUrl,
  }) async {
    await _c.from('bookings').update({
      'house_rules_accepted_at': DateTime.now().toIso8601String(),
      if (signatureUrl != null) 'house_rules_signature_url': signatureUrl,
    }).eq('id', id);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _c.from('bookings').update(patch).eq('id', id);
  }
}

final bookingsRepoProvider = Provider((_) => BookingsRepository());

final upcomingBookingsProvider =
FutureProvider<List<BookingOverview>>((ref) async {
  return ref.read(bookingsRepoProvider).listUpcoming();
});

final inHouseBookingsProvider =
FutureProvider<List<BookingOverview>>((ref) async {
  return ref.read(bookingsRepoProvider).listInHouse();
});

final bookingDetailProvider =
FutureProvider.family<BookingOverview?, String>((ref, id) async {
  return ref.read(bookingsRepoProvider).getById(id);
});
final pastBookingsProvider =
FutureProvider<List<BookingOverview>>((ref) async {
  return ref.read(bookingsRepoProvider).listPast();
});