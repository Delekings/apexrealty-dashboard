// lib/features/contracts/providers/contracts_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/contracts_repository.dart';

final contractsRepoProvider = Provider((_) => ContractsRepository());

final contractDetailProvider =
FutureProvider.autoDispose.family<ContractDetail, String>((ref, id) async {
  final repo = ref.read(contractsRepoProvider);
  return repo.getDetail(id);
});

final contractsListProvider =
FutureProvider.autoDispose<List<ContractListItem>>((ref) async {
  final repo = ref.read(contractsRepoProvider);
  return repo.listByAgency();
});