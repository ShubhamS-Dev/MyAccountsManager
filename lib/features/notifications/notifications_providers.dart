import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/today_provider.dart';
import '../my_khata/data/khata_repository.dart';
import '../my_khata/khata_providers.dart';
import '../settings/settings_providers.dart';
import '../transactions/data/transactions_repository.dart';
import '../transactions/transactions_providers.dart';
import 'data/notification_gateway.dart';
import 'data/notification_preferences.dart';
import 'domain/reminder_planner.dart';

/// Real notifications on Android; a no-op elsewhere, including widget tests.
final notificationGatewayProvider = Provider<NotificationGateway>((ref) {
  return Platform.isAndroid
      ? LocalNotificationGateway()
      : const NoopNotificationGateway();
});

final notificationPreferencesProvider = StreamProvider<NotificationPreferences>(
  (ref) {
    return ref
        .watch(settingsRepositoryProvider)
        .watchValuesWithPrefix(notificationSettingPrefix)
        .map(NotificationPreferences.fromStorage);
  },
);

Future<void> saveNotificationSetting(WidgetRef ref, String key, Object value) {
  return ref.read(settingsRepositoryProvider).setValue(key, '$value');
}

/// Permission and timing state. Invalidate after the user may have changed
/// it in system settings, e.g. when the app resumes.
final notificationStatusProvider = FutureProvider<NotificationStatus>((ref) {
  return ref.watch(notificationGatewayProvider).status();
});

/// Non-deleted transactions dated after today, i.e. Scheduled.
final scheduledTransactionsProvider =
    StreamProvider<List<TransactionHistoryItem>>((ref) {
      final today = ref.watch(todayProvider);
      return ref
          .watch(transactionsRepositoryProvider)
          .watchHistory(fromDate: today + Duration.millisecondsPerDay);
    });

final _allKhataEntriesProvider = Provider<AsyncValue<List<KhataEntryItem>>>(
  (ref) => ref.watch(khataEntriesProvider(null)),
);

final activityDigestProvider = Provider<AsyncValue<ActivityDigest>>((ref) {
  final today = ref.watch(todayProvider);
  final entries = ref.watch(_allKhataEntriesProvider);
  final scheduled = ref.watch(scheduledTransactionsProvider);
  if (entries.hasError) {
    return AsyncError(entries.error!, entries.stackTrace!);
  }
  if (scheduled.hasError) {
    return AsyncError(scheduled.error!, scheduled.stackTrace!);
  }
  if (!entries.hasValue || !scheduled.hasValue) return const AsyncLoading();
  return AsyncData(
    ActivityDigest.build(
      khataEntries: entries.requireValue,
      scheduledTransactions: scheduled.requireValue,
      today: today,
    ),
  );
});

/// Overdue plus due-today MyKhata entries, for the bell badge.
final attentionCountProvider = Provider<int>((ref) {
  final today = ref.watch(todayProvider);
  final entries = ref.watch(_allKhataEntriesProvider).valueOrNull ?? const [];
  return ActivityDigest.build(
    khataEntries: entries,
    scheduledTransactions: const [],
    today: today,
  ).attentionCount;
});

/// The full set of reminders that should be pending right now.
final reminderPlanProvider = Provider<AsyncValue<List<PlannedReminder>>>((ref) {
  ref.watch(todayProvider);
  final entries = ref.watch(_allKhataEntriesProvider);
  final scheduled = ref.watch(scheduledTransactionsProvider);
  final preferences = ref.watch(notificationPreferencesProvider);
  if (!entries.hasValue || !scheduled.hasValue || !preferences.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData(
    planReminders(
      khataEntries: entries.requireValue,
      scheduledTransactions: scheduled.requireValue,
      preferences: preferences.requireValue,
      now: DateTime.now(),
    ),
  );
});
