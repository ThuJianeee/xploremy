import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme_controller.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<ThemeMode>(
          initialValue: controller.mode,
          decoration: const InputDecoration(
            labelText: 'Appearance',
            prefixIcon: Icon(Icons.brightness_6_outlined),
          ),
          items: const [
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text('Follow system'),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text('Light'),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text('Dark'),
            ),
          ],
          onChanged: (mode) {
            if (mode != null) controller.setMode(mode);
          },
        ),
      ),
    );
  }
}
