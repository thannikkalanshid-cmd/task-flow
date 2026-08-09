import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final value = (await SharedPreferences.getInstance()).getString('theme_mode');
    _mode = ThemeMode.values.firstWhere((mode) => mode.name == value, orElse: () => ThemeMode.system);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString('theme_mode', mode.name);
  }

  Future<void> toggle() {
    return setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
