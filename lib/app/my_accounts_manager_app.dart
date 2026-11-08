import 'package:flutter/material.dart';

import 'app_router.dart';

class MyAccountsManagerApp extends StatelessWidget {
  const MyAccountsManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF315C4C);

    return MaterialApp.router(
      title: 'MyAccountsManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F8F6),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
