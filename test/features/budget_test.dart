import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_accounts_manager/app/app_theme.dart';
import 'package:my_accounts_manager/app/privacy_state.dart';
import 'package:my_accounts_manager/core/database/app_database.dart';
import 'package:my_accounts_manager/core/time/today_provider.dart';
import 'package:my_accounts_manager/features/budgets/budget_providers.dart';
import 'package:my_accounts_manager/features/budgets/domain/budget.dart';
import 'package:my_accounts_manager/features/budgets/presentation/budget_alert_sync.dart';
import 'package:my_accounts_manager/features/budgets/presentation/budget_page.dart';
import 'package:my_accounts_manager/features/notifications/data/notification_gateway.dart';
import 'package:my_accounts_manager/features/notifications/data/notification_preferences.dart';
import 'package:my_accounts_manager/features/notifications/notifications_providers.dart';
import 'package:my_accounts_manager/features/settings/data/settings_repository.dart';
import 'package:my_accounts_manager/features/settings/settings_providers.dart';

final november11 = DateTime(2026, 11, 11);

BudgetStatus status(int spent, {int limit = 5000000, DateTime? date}) =>
    BudgetStatus(
      limitPaise: limit,
      spentPaise: spent,
      date: date ?? november11,
    );

/// In-memory settings that publish every write as new [BudgetSettings].
class _FakeSettings extends SettingsRepository {
  _FakeSettings(super.database, this.values, this.controller);

  final Map<String, String> values;
  final StreamController<BudgetSettings> controller;

  @override
  Future<void> setValue(String key, String value) async {
    values[key] = value;
    controller.add(BudgetSettings.fromStorage(values));
  }
}

class _RecordingGateway extends NoopNotificationGateway {
  final shown = <(String, String)>[];

  @override
  bool get supported => true;

  @override
  Future<void> showNow({
    required String key,
    required String title,
    required String body,
    required String route,
  }) async => shown.add((title, body));
}

void main() {
  group('BudgetStatus', () {
    test('levels and thresholds', () {
      expect(status(3000000).level, BudgetLevel.onTrack);
      expect(status(3000000).thresholdReached, 0);
      expect(status(4000000).level, BudgetLevel.warning);
      expect(status(4000000).thresholdReached, 80);
      expect(status(5000000).level, BudgetLevel.over);
      expect(status(6000000).thresholdReached, 100);
    });

    test('daily allowance spreads what is left over the remaining days', () {
      final current = status(2000000);
      expect(current.daysLeft, 20); // 11th to 30th November.
      expect(current.dailyAllowancePaise, 150000);
      expect(status(6000000).dailyAllowancePaise, 0);
      expect(status(0, date: DateTime(2026, 11, 30)).daysLeft, 1);
    });

    test('alert text hides amounts unless allowed', () {
      final hidden = budgetAlertText(status(4000000), 80, showAmounts: false);
      expect(hidden.title, '80% of monthly budget used');
      expect(hidden.body, isNot(contains('₹')));
      final shown = budgetAlertText(status(5500000), 100, showAmounts: true);
      expect(shown.title, 'Monthly budget exceeded');
      expect(shown.body, '₹55,000 spent of ₹50,000. Over by ₹5,000.');
    });

    test('settings parse limit, toggle and alerted months', () {
      final settings = BudgetSettings.fromStorage({
        budgetLimitKey: '5000000',
        budgetAlertsKey: 'false',
        budgetAlertedKey(november11): '80',
      });
      expect(settings.limitPaise, 5000000);
      expect(settings.alertsEnabled, isFalse);
      expect(settings.alertedFor(november11), 80);
      expect(
        BudgetSettings.fromStorage({budgetLimitKey: '0'}).limitPaise,
        null,
      );
    });
  });

  group('alerts and screen', () {
    late AppDatabase database;
    late StreamController<BudgetSettings> settingsStream;
    late Map<String, String> values;
    late _RecordingGateway gateway;
    final spent = StateProvider<int>((ref) => 0);

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      settingsStream = StreamController<BudgetSettings>.broadcast();
      values = {budgetLimitKey: '5000000'};
      gateway = _RecordingGateway();
    });

    tearDown(() async {
      await settingsStream.close();
      await database.close();
    });

    Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
      final initial = BudgetSettings.fromStorage(values);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettings(database, values, settingsStream),
            ),
            budgetSettingsProvider.overrideWith((ref) async* {
              yield initial;
              yield* settingsStream.stream;
            }),
            monthExpensePaiseProvider.overrideWith(
              (ref) => AsyncData(ref.watch(spent)),
            ),
            todayProvider.overrideWithValue(
              DateTime.utc(2026, 11, 11).millisecondsSinceEpoch,
            ),
            notificationGatewayProvider.overrideWithValue(gateway),
            notificationPreferencesProvider.overrideWith(
              (ref) => Stream.value(
                const NotificationPreferences(showAmounts: true),
              ),
            ),
            storedAmountsHiddenProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light),
            home: child,
          ),
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byWidget(child)));
    }

    testWidgets('alerts once at 80%, once at 100%, and re-arms', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const BudgetAlertSync(child: SizedBox()),
      );

      container.read(spent.notifier).state = 3000000;
      await tester.pump();
      expect(gateway.shown, isEmpty);

      container.read(spent.notifier).state = 4100000;
      await tester.pump();
      await tester.pump();
      container.read(spent.notifier).state = 4200000;
      await tester.pump();
      await tester.pump();
      expect(gateway.shown.map((alert) => alert.$1), [
        '80% of monthly budget used',
      ]);

      container.read(spent.notifier).state = 5200000;
      await tester.pump();
      await tester.pump();
      expect(gateway.shown.last.$1, 'Monthly budget exceeded');
      expect(gateway.shown, hasLength(2));

      // A deleted expense drops below 80%; crossing again alerts again.
      container.read(spent.notifier).state = 1000000;
      await tester.pump();
      await tester.pump();
      expect(values[budgetAlertedKey(november11)], '0');
      container.read(spent.notifier).state = 4500000;
      await tester.pump();
      await tester.pump();
      expect(gateway.shown, hasLength(3));
    });

    testWidgets('the alert switch silences notifications', (tester) async {
      values[budgetAlertsKey] = 'false';
      final container = await pump(
        tester,
        const BudgetAlertSync(child: SizedBox()),
      );
      container.read(spent.notifier).state = 4500000;
      await tester.pump();
      await tester.pump();
      expect(gateway.shown, isEmpty);
      expect(values[budgetAlertedKey(november11)], '80');
    });

    testWidgets('Budget screen shows progress and saving a limit is silent', (
      tester,
    ) async {
      final container = await pump(tester, const BudgetPage());
      container.read(spent.notifier).state = 4500000;
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('budget-progress-card')),
        findsOneWidget,
      );
      expect(find.text('₹5,000 left'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('₹250/day for 20 days'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('budget-limit-input')),
        '40,000',
      );
      await tester.tap(find.text('Update budget'));
      await tester.pump();
      await tester.pump();
      expect(values[budgetLimitKey], '4000000');
      // Already over the new limit: recorded as alerted, so no notification.
      expect(values[budgetAlertedKey(november11)], '100');
      expect(find.text('Over by ₹5,000'), findsOneWidget);
    });
  });
}
