import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../formatting/date_timestamp.dart';

/// The device's current local calendar date as stored UTC-midnight
/// milliseconds. Rebuilds itself just after local midnight so balances and
/// scheduled transactions roll over without an app restart.
final todayProvider = Provider<int>((ref) {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(
    nextMidnight.difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return DateOnly.toUtcEpochMilliseconds(now);
});

/// Whether a stored business date falls after [today], i.e. the transaction
/// is scheduled and does not count towards balances or totals yet.
bool isScheduledDate(int storedDate, int today) =>
    storedDate >= today + Duration.millisecondsPerDay;
