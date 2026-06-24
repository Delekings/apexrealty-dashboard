// lib/features/email/providers/email_audiences_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/email_audiences_repository.dart';

final emailAudiencesRepoProvider =
    Provider((_) => EmailAudiencesRepository());

/// All saved audiences for the current agency, newest first.
final emailAudiencesProvider =
    FutureProvider.autoDispose<List<EmailAudience>>((ref) async {
  final repo = ref.read(emailAudiencesRepoProvider);
  return repo.list();
});
