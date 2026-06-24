// lib/features/finances/providers/expenses_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/expenses_repository.dart';
import '../../../data/repositories/recurring_repository.dart';

final expensesRepoProvider = Provider((_) => ExpensesRepository());

/// All expenses for the current agency, newest spend first.
final expensesProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) async {
  // Auto-post any due recurring expenses before listing (best-effort).
  try {
    await RecurringRepository().materializeDue();
  } catch (_) {}
  return ref.read(expensesRepoProvider).list();
});
