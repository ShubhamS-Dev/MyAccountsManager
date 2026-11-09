import 'package:flutter/material.dart';

import 'app_router.dart';
import 'app_theme.dart';

class MyAccountsManagerApp extends StatelessWidget {
  const MyAccountsManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyAccountsManager',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness: Brightness.light),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
