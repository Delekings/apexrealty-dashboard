import 'package:flutter_riverpod/legacy.dart';
// lib/features/properties/providers/properties_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/properties_repository.dart';

final propertiesRepoProvider = Provider((_) => PropertiesRepository());

class PropertiesFilter {
  final String search;
  final PropertyStatus? status;
  final int page;
  const PropertiesFilter({
    this.search = '',
    this.status,
    this.page = 0,
  });

  PropertiesFilter copyWith({
    String? search,
    PropertyStatus? status,
    int? page,
    bool clearStatus = false,
  }) {
    return PropertiesFilter(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
    );
  }
}

final propertiesFilterProvider =
StateProvider<PropertiesFilter>((_) => const PropertiesFilter());

final propertiesPageProvider =
FutureProvider.autoDispose<PropertiesPage>((ref) async {
  final filter = ref.watch(propertiesFilterProvider);
  final repo = ref.read(propertiesRepoProvider);
  return repo.list(
    search: filter.search,
    status: filter.status,
    page: filter.page,
  );
});

final propertyDetailProvider =
FutureProvider.autoDispose.family<Property, String>((ref, id) async {
  final repo = ref.read(propertiesRepoProvider);
  return repo.get(id);
});

/// Unit types for a single property (rooms in a hotel, plot variants in an estate).
final propertyUnitTypesProvider =
FutureProvider.autoDispose.family<List<PropertyUnitType>, String>(
        (ref, propertyId) async {
      final repo = ref.read(propertiesRepoProvider);
      return repo.getUnitTypes(propertyId);
    });