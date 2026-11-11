import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'data/khata_repository.dart';

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  return KhataRepository(ref.watch(appDatabaseProvider));
});

final khataPeopleSummariesProvider = StreamProvider<List<KhataPersonSummary>>((
  ref,
) {
  return ref.watch(khataRepositoryProvider).watchPeopleSummaries();
});

/// Derived from the people stream so totals and the list never disagree.
final khataTotalsProvider = Provider<AsyncValue<KhataTotals>>((ref) {
  return ref
      .watch(khataPeopleSummariesProvider)
      .whenData(KhataTotals.fromSummaries);
});

/// Entries for one person, or all people when the key is null.
final khataEntriesProvider =
    StreamProvider.family<List<KhataEntryItem>, String?>((ref, personId) {
      return ref
          .watch(khataRepositoryProvider)
          .watchEntries(personId: personId);
    });

final khataEntryProvider = StreamProvider.family<KhataEntryItem?, String>((
  ref,
  entryId,
) {
  return ref.watch(khataRepositoryProvider).watchEntry(entryId);
});

final khataPersonProvider = StreamProvider.family<KhataPersonRow?, String>((
  ref,
  personId,
) {
  return ref.watch(khataRepositoryProvider).watchPerson(personId);
});

final khataRepaymentsProvider =
    StreamProvider.family<List<KhataRepaymentRow>, String>((ref, entryId) {
      return ref.watch(khataRepositoryProvider).watchRepayments(entryId);
    });
