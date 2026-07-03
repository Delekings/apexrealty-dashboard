import 'package:flutter_riverpod/legacy.dart';
// lib/features/clients/providers/clients_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/clients_repository.dart';

final clientsRepoProvider = Provider((_) => ClientsRepository());

/// Search/filter state for the list view.
class ClientsListFilter {
  final String search;
  final String? agentId;
  final int page;
  const ClientsListFilter({
    this.search = '',
    this.agentId,
    this.page = 0,
  });

  ClientsListFilter copyWith({String? search, String? agentId, int? page, bool clearAgent = false}) {
    return ClientsListFilter(
      search: search ?? this.search,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      page: page ?? this.page,
    );
  }
}

final clientsFilterProvider = StateProvider<ClientsListFilter>((_) => const ClientsListFilter());

final clientsPageProvider = FutureProvider.autoDispose<ClientsPage>((ref) async {
  final filter = ref.watch(clientsFilterProvider);
  final repo = ref.read(clientsRepoProvider);
  return repo.list(
    search: filter.search,
    agentId: filter.agentId,
    page: filter.page,
  );
});

final agentsListProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  final repo = ref.read(clientsRepoProvider);
  return repo.listAgents();
});

final clientDetailProvider =
    FutureProvider.autoDispose.family<ClientDetail, String>((ref, id) async {
  final repo = ref.read(clientsRepoProvider);
  return repo.getDetail(id);
});

final allClientsForPickerProvider =
FutureProvider.autoDispose<List<ClientListItem>>((ref) async {
  final repo = ref.read(clientsRepoProvider);
  return repo.listAllForPicker();
});