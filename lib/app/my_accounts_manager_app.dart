import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/presentation/reminder_sync.dart';
import '../features/settings/settings_providers.dart';
import 'app_router.dart';
import 'app_theme.dart';

class MyAccountsManagerApp extends ConsumerWidget {
  const MyAccountsManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follow the device until the stored Appearance preference has loaded.
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return ReminderSync(
      child: MaterialApp.router(
        title: 'MyAccountsManager',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 250),
        routerConfig: appRouter,
      ),
    );
  }
}
