import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';

class EstanteDigitalApp extends StatelessWidget {
  const EstanteDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3D5A80))
        .copyWith(
          primary: const Color(0xFF3D5A80),
          secondary: const Color(0xFFEE6C4D),
          surface: const Color(0xFFF5F1E8),
        );

    return MaterialApp(
      title: 'Estante Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8F4EC),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
