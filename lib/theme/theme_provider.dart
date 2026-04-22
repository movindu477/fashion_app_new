import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemes {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5200),
      brightness: Brightness.light,
      surface: const Color(0xFFF8F8F8),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F0F0),
    ),
    useMaterial3: true,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFFF8F8F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F8F8),
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
      headlineMedium: TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
      titleLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.black87),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, color: Colors.black87),
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5200),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F0F0F),
      surfaceContainerLowest: const Color(0xFF1A1A1A),
      surfaceContainerLow: const Color(0xFF161616),
    ),
    useMaterial3: true,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0F0F),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
      headlineMedium: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
      titleLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, color: Colors.white70),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeKey);
    if (themeModeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeModeString,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
    notifyListeners();
  }

  void toggleTheme() {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setTheme(newMode);
  }
}
