// lib/features/shortlet/widgets/property_shortlet_card.dart
//
// Goes on the property detail screen. Shows the property's shortlet
// status:
//   - No listing → "Make bookable" CTA
//   - Whole-property listing → summary card with edit
//   - Multi-unit → one row per unit type (listed or "+ add")

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/rental_listings_repository.dart';
import '../../properties/providers/properties_providers.dart';
import 'rental_listing_dialog.dart';

class PropertyShortletCard extends ConsumerWidget {
  final Property property;
  const PropertyShortletCard({super.key, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync =
    ref.watch(propertyListingsProvider(property.id));
    final unitTypesAsync =
    ref.watch(propertyUnitTypesProvider(property.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: listingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.brand, strokeWidth: 2))),
          ),
          error: (e, _) => Text('Could not load shortlet info: $e',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.danger)),
          data: (listings) {
            final unitTypes = unitTypesAsync.valueOrNull ?? const [];
            return _buildContent(context, ref, listings, unitTypes);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      WidgetRef ref,
      List<RentalListing> listings,
      List<PropertyUnitType> unitTypes,
      ) {
    // CASE 1: No listings at all
    if (listings.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.king_bed_outlined,
                  size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              const Text('Shortlet / Hotel',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Make this property bookable for short stays',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set nightly pricing, house rules and amenities — guests will be able to book it for nights or weeks.',
            style: TextStyle(
                fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Set up rental listing'),
              onPressed: () => _openDialog(context, ref, unitTypes),
            ),
          ),
        ],
      );
    }

    // CASE 2: Whole-property listing (one listing with null unit_type_id)
    final wholeProperty =
        listings.where((l) => l.propertyUnitTypeId == null).firstOrNull;
    if (wholeProperty != null) {
      return _wholePropertyView(context, ref, wholeProperty, unitTypes);
    }

    // CASE 3: Per-unit listings (one or more, each with a unit_type_id)
    return _perUnitView(context, ref, listings, unitTypes);
  }

  Widget _wholePropertyView(
      BuildContext context,
      WidgetRef ref,
      RentalListing listing,
      List<PropertyUnitType> unitTypes,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.king_bed_outlined,
                size: 16, color: AppColors.brand),
            const SizedBox(width: 6),
            const Text('Shortlet / Hotel listing',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.5)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: listing.isActive
                    ? AppColors.brandLight
                    : AppColors.bg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                listing.isActive ? 'Active' : 'Paused',
                style: TextStyle(
                    fontSize: 10,
                    color: listing.isActive
                        ? AppColors.brand
                        : AppColors.muted,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${Formatters.naira(listing.nightlyRateNgn)}/night',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Sleeps ${listing.maxGuests} · check-in ${listing.checkInTime} · check-out ${listing.checkOutTime}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        if (listing.amenities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: listing.amenities
                .take(6)
                .map((a) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(a,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted)),
            ))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
              onPressed: () =>
                  _openDialog(context, ref, unitTypes, existing: listing),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: Icon(
                listing.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 14,
              ),
              label: Text(listing.isActive ? 'Pause' : 'Activate'),
              onPressed: () => _toggleActive(ref, listing),
            ),
          ],
        ),
      ],
    );
  }

  Widget _perUnitView(
      BuildContext context,
      WidgetRef ref,
      List<RentalListing> listings,
      List<PropertyUnitType> unitTypes,
      ) {
    final byUnit = {for (final l in listings) l.propertyUnitTypeId!: l};
    final listedCount = listings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.king_bed_outlined,
                size: 16, color: AppColors.brand),
            const SizedBox(width: 6),
            const Text('Shortlet / Hotel listings',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text(
              '$listedCount of ${unitTypes.length} units listed',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final unitType in unitTypes) ...[
          _unitRow(context, ref, unitType, byUnit[unitType.id], unitTypes),
          if (unitType != unitTypes.last) const Divider(height: 16),
        ],
      ],
    );
  }

  Widget _unitRow(
      BuildContext context,
      WidgetRef ref,
      PropertyUnitType unitType,
      RentalListing? listing,
      List<PropertyUnitType> unitTypes,
      ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(unitType.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                listing == null
                    ? 'Not listed for short stays'
                    : '${Formatters.naira(listing.nightlyRateNgn)}/night · sleeps ${listing.maxGuests}',
                style: TextStyle(
                    fontSize: 11,
                    color: listing == null
                        ? AppColors.muted
                        : AppColors.text),
              ),
            ],
          ),
        ),
        if (listing == null)
          TextButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('List'),
            onPressed: () => _openDialog(
              context,
              ref,
              unitTypes,
              prefilledUnitTypeId: unitType.id,
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () =>
                _openDialog(context, ref, unitTypes, existing: listing),
          ),
      ],
    );
  }

  Future<void> _openDialog(
      BuildContext context,
      WidgetRef ref,
      List<PropertyUnitType> unitTypes, {
        RentalListing? existing,
        String? prefilledUnitTypeId,
      }) async {
    await showDialog(
      context: context,
      builder: (_) => RentalListingDialog(
        propertyId: property.id,
        unitTypes: unitTypes,
        existing: existing,
        prefilledUnitTypeId: prefilledUnitTypeId,
      ),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, RentalListing listing) async {
    await ref
        .read(rentalListingsRepoProvider)
        .setActive(listing.id, !listing.isActive);
    ref.invalidate(propertyListingsProvider(property.id));
  }
}