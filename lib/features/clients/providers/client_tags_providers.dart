// lib/features/clients/providers/client_tags_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/client_tags_repository.dart';

final clientTagsRepoProvider = Provider((_) => ClientTagsRepository());

/// All tags for the current agency (used by pickers and the campaign filter).
final clientTagsProvider =
    FutureProvider.autoDispose<List<ClientTag>>((ref) async {
  final repo = ref.read(clientTagsRepoProvider);
  return repo.listTags();
});

/// Tag ids currently assigned to a specific client (for the edit flow).
final clientTagIdsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, clientId) async {
  final repo = ref.read(clientTagsRepoProvider);
  return repo.tagIdsForClient(clientId);
});
