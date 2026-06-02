// lib/data/repositories/rental_listings_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class RentalListingsRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Listings for one property (could be one whole-property listing
  /// OR many per-unit-type listings for a hotel).
  Future<List<RentalListing>> listForProperty(String propertyId) async {
    final rows = await _c
        .from('rental_listings')
        .select()
        .eq('property_id', propertyId)
        .order('created_at');
    return (rows as List)
        .map((r) => RentalListing.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// All active rental listings in the agency.
  Future<List<RentalListing>> listAllActive() async {
    final rows = await _c
        .from('rental_listings')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => RentalListing.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<RentalListing?> getById(String id) async {
    final row = await _c
        .from('rental_listings')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : RentalListing.fromMap(row);
  }

  /// Create a new rental listing for a property (or one of its unit types).
  Future<String> create({
    required String agencyId,
    required String propertyId,
    String? propertyUnitTypeId,
    required num nightlyRateNgn,
    num? weeklyRateNgn,
    num? monthlyRateNgn,
    num cleaningFeeNgn = 0,
    num securityDepositNgn = 0,
    String checkInTime = '15:00',
    String checkOutTime = '11:00',
    int minNights = 1,
    int maxNights = 30,
    required int maxGuests,
    String? description,
    List<String> amenities = const [],
    String? houseRulesMarkdown,
    CancellationPolicy cancellationPolicy = CancellationPolicy.moderate,
  }) async {
    final res = await _c
        .from('rental_listings')
        .insert({
      'agency_id': agencyId,
      'property_id': propertyId,
      if (propertyUnitTypeId != null)
        'property_unit_type_id': propertyUnitTypeId,
      'nightly_rate_ngn': nightlyRateNgn,
      if (weeklyRateNgn != null) 'weekly_rate_ngn': weeklyRateNgn,
      if (monthlyRateNgn != null) 'monthly_rate_ngn': monthlyRateNgn,
      'cleaning_fee_ngn': cleaningFeeNgn,
      'security_deposit_ngn': securityDepositNgn,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
      'min_nights': minNights,
      'max_nights': maxNights,
      'max_guests': maxGuests,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'amenities': amenities,
      if (houseRulesMarkdown != null && houseRulesMarkdown.trim().isNotEmpty)
        'house_rules_markdown': houseRulesMarkdown.trim(),
      'cancellation_policy': cancellationPolicyToDb(cancellationPolicy),
    })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _c.from('rental_listings').update(patch).eq('id', id);
  }

  Future<void> setActive(String id, bool active) async {
    await _c
        .from('rental_listings')
        .update({'is_active': active}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('rental_listings').delete().eq('id', id);
  }
}

final rentalListingsRepoProvider = Provider((_) => RentalListingsRepository());

final propertyListingsProvider =
FutureProvider.family<List<RentalListing>, String>(
        (ref, propertyId) async {
      return ref.read(rentalListingsRepoProvider).listForProperty(propertyId);
    });

final allActiveListingsProvider =
FutureProvider<List<RentalListing>>((ref) async {
  return ref.read(rentalListingsRepoProvider).listAllActive();
});