// lib/features/properties/presentation/widgets/unit_inventory_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../providers/properties_providers.dart';

/// Per-property unit-types provider. Cached per property id so it
/// doesn't refetch on rebuild.
final unitTypesForPropertyProvider =
FutureProvider.family<List<PropertyUnitType>, String>(
        (ref, propertyId) async {
      return ref.read(propertiesRepoProvider).getUnitTypes(propertyId);
    });

/// Card that lists every unit type for a property with its availability
/// stats and a "Sell unit" button per row that deep-links to the new
/// contract screen with both the property and unit type pre-selected.
class UnitInventoryCard extends ConsumerWidget {
  final String propertyId;
  const UnitInventoryCard({super.key, required this.propertyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unitTypesForPropertyProvider(propertyId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Unit inventory',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh,
                    size: 16, color: AppColors.muted),
                onPressed: () => ref.invalidate(
                    unitTypesForPropertyProvider(propertyId)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brand),
                  )),
            ),
            error: (e, _) => Text(
              'Could not load units: $e',
              style:
              const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
            data: (types) {
              if (types.isEmpty) {
                return const Text(
                  'No unit types defined for this property.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                );
              }
              return Column(
                children: [
                  for (final t in types) _UnitRow(unit: t),
                  const SizedBox(height: 4),
                  _OverallSummary(types: types),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final PropertyUnitType unit;
  const _UnitRow({required this.unit});

  @override
  Widget build(BuildContext context) {
    final available = unit.availableUnits;
    final sold = unit.soldUnits;
    final reserved = unit.reservedUnits;
    final canSell = available > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(unit.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (unit.sizeSqm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${unit.sizeSqm} sqm',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.brand,
                                fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _stat('Available', '$available',
                        color: available > 0
                            ? AppColors.brand
                            : AppColors.muted),
                    if (reserved > 0)
                      _stat('Reserved', '$reserved',
                          color: AppColors.gold),
                    if (sold > 0)
                      _stat('Sold', '$sold', color: AppColors.muted),
                    _stat('Total', '${unit.totalUnits}',
                        color: AppColors.text),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.naira(unit.basePriceNgn),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('per unit',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.muted)),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: canSell
                    ? () => context.go(
                  '/contracts/new'
                      '?property=${unit.propertyId}'
                      '&unit_type=${unit.id}',
                )
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.shopping_cart_outlined,
                    size: 12),
                label: Text(
                  canSell ? 'Sell unit' : 'Sold out',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 10, color: AppColors.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

class _OverallSummary extends StatelessWidget {
  final List<PropertyUnitType> types;
  const _OverallSummary({required this.types});

  @override
  Widget build(BuildContext context) {
    final total = types.fold<int>(0, (s, u) => s + u.totalUnits);
    final available = types.fold<int>(0, (s, u) => s + u.availableUnits);
    final reserved = types.fold<int>(0, (s, u) => s + u.reservedUnits);
    final sold = types.fold<int>(0, (s, u) => s + u.soldUnits);
    final progress = total == 0 ? 0.0 : (sold + reserved) / total;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_outlined,
                  size: 12, color: AppColors.brand),
              const SizedBox(width: 6),
              Text('$available of $total units available',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand)),
              const Spacer(),
              if (reserved > 0)
                Text('$reserved reserved',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 4,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}