// lib/features/finances/providers/recurring_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/recurring_repository.dart';

final recurringRepoProvider = Provider((_) => RecurringRepository());

/// All recurring expense rules for the current agency, newest first.
final recurringListProvider =
    FutureProvider.autoDispose<List<RecurringExpense>>((ref) async {
  return ref.read(recurringRepoProvider).list();
});
