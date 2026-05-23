// lib/features/properties/presentation/screens/properties_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/properties_repository.dart';
import '../../providers/properties_providers.dart';

class PropertiesScreen extends ConsumerStatefulWidget {
  const PropertiesScreen({super.key});

  @override
  ConsumerState<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends ConsumerState<PropertiesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final f = ref.read(propertiesFilterProvider);
      ref.read(propertiesFilterProvider.notifier).state =
          f.copyWith(search: v, page: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(propertiesFilterProvider);
    final pageAsync = ref.watch(propertiesPageProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Properties',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Estates and developments — your sellable inventory.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/properties/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add property'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: AppColors.muted),
                    hintText: 'Search by title, location, or state',
                    hintStyle:
                    TextStyle(fontSize: 13, color: AppColors.muted),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<PropertyStatus?>(
                  value: filter.status,
                  isDense: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.filter_list,
                        size: 18, color: AppColors.muted),
                    isDense: true,
                  ),
                  hint: const Text('Filter by status',
                      style:
                      TextStyle(fontSize: 13, color: AppColors.muted)),
                  items: [
                    const DropdownMenuItem<PropertyStatus?>(
                      value: null,
                      child: Text('All statuses',
                          style: TextStyle(fontSize: 13)),
                    ),
                    for (final s in PropertyStatus.values)
                      DropdownMenuItem<PropertyStatus?>(
                        value: s,
                        child: Text(_statusLabel(s),
                            style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (v) {
                    ref.read(propertiesFilterProvider.notifier).state =
                        filter.copyWith(
                          status: v,
                          clearStatus: v == null,
                          page: 0,
                        );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid
          Expanded(
            child: pageAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
              error: (e, _) => Center(
                child: Text('Failed to load: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.home_work_outlined,
                    title: filter.search.isEmpty && filter.status == null
                        ? 'No properties yet'
                        : 'No properties match your filters',
                    message: filter.search.isEmpty && filter.status == null
                        ? 'Add your first property to start selling.'
                        : 'Try clearing the search or status filter.',
                    action: (filter.search.isEmpty && filter.status == null)
                        ? FilledButton.icon(
                      onPressed: () =>
                          context.go('/properties/new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add your first property'),
                    )
                        : null,
                  );
                }
                return _PropertiesGrid(page: page);
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(PropertyStatus s) => switch (s) {
  PropertyStatus.available => 'Available',
  PropertyStatus.reserved => 'Reserved',
  PropertyStatus.partiallySold => 'Partially sold',
  PropertyStatus.soldOut => 'Sold out',
  PropertyStatus.inactive => 'Inactive',
};

Color _statusColor(PropertyStatus s) => switch (s) {
  PropertyStatus.available => AppColors.brand,
  PropertyStatus.reserved => AppColors.gold,
  PropertyStatus.partiallySold => AppColors.info,
  PropertyStatus.soldOut => AppColors.muted,
  PropertyStatus.inactive => AppColors.muted,
};

class _PropertiesGrid extends StatelessWidget {
  final PropertiesPage page;
  const _PropertiesGrid({required this.page});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 1200 ? 4 : (w >= 800 ? 3 : (w >= 560 ? 2 : 1));

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: page.items.length,
      itemBuilder: (_, i) => _PropertyCard(property: page.items[i]),
    );
  }
}

/// A property card that loads its own unit-type summary asynchronously
/// so the grid renders fast (basic info from the property row first,
/// unit details fill in shortly after).
class _PropertyCard extends ConsumerWidget {
  final Property property;
  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(_unitTypesGridProvider(property.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/properties/${property.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (property.coverImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: property.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.bg2,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.brand),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.bg2,
                        child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.muted),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.brandLight,
                      child: const Center(
                        child: Icon(Icons.home_work_outlined,
                            size: 36, color: AppColors.brand),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(property.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(property.status),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 12, color: AppColors.muted),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${property.location}, ${property.state}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    unitsAsync.when(
                      loading: () => _legacySummary(),
                      error: (_, __) => _legacySummary(),
                      data: (units) => units.isEmpty
                          ? _legacySummary()
                          : _unitTypeSummary(units),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback summary using the legacy properties.total_units columns.
  /// Used while loading or if no unit types are defined.
  Widget _legacySummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          Formatters.nairaCompact(property.basePrice),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brand),
        ),
        Text(
          property.totalUnits > 1
              ? '${property.availableUnits}/${property.totalUnits} units'
              : (property.availableUnits > 0 ? 'Available' : 'Sold'),
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }

  /// Rich summary computed from actual unit types.
  /// - Price shows a range if multiple types, single price if uniform.
  /// - Unit count shows live available / total.
  Widget _unitTypeSummary(List<PropertyUnitType> units) {
    final totalUnits = units.fold<int>(0, (s, u) => s + u.totalUnits);
    final availableUnits =
    units.fold<int>(0, (s, u) => s + u.availableUnits);

    final prices = units.map((u) => u.basePriceNgn).toList()
      ..sort((a, b) => a.compareTo(b));
    final minPrice = prices.first;
    final maxPrice = prices.last;
    final priceLabel = minPrice == maxPrice
        ? Formatters.nairaCompact(minPrice)
        : '${Formatters.nairaCompact(minPrice)}–${Formatters.nairaCompact(maxPrice)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          priceLabel,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brand),
        ),
        Text(
          totalUnits > 1
              ? '$availableUnits/$totalUnits units'
              : (availableUnits > 0 ? 'Available' : 'Sold'),
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Per-property unit-types provider used by the grid cards.
/// Cached so the same property doesn't refetch on rebuild.
final _unitTypesGridProvider =
FutureProvider.family<List<PropertyUnitType>, String>(
        (ref, propertyId) async {
      return ref.read(propertiesRepoProvider).getUnitTypes(propertyId);
    });