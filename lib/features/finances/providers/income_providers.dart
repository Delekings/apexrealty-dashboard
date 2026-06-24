// lib/features/finances/providers/income_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/income_repository.dart';

final incomeRepoProvider = Provider((_) => IncomeRepository());

/// All other income for the current agency, newest first.
final incomeProvider =
    FutureProvider.autoDispose<List<OtherIncome>>((ref) async {
  return ref.read(incomeRepoProvider).list();
});
