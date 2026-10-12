import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF0B3D2E);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: const Color(0xFFF7F4EC),
    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    visualDensity: VisualDensity.standard,
  );
}
