import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/core/theme_controller.dart';

void main() {
  test('loads stored theme mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final controller = ThemeController();

    await controller.load();

    expect(controller.mode, ThemeMode.dark);
  });

  test('persists selected theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    await controller.setMode(ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();

    expect(controller.mode, ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');
  });
}
