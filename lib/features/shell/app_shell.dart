import 'package:flutter/material.dart';

import '../data_sync/data_screen.dart';
import '../home/home_screen.dart';
import '../planner/route_planner_screen.dart';
import '../profile/profile_edit_controller.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _profileIndex = 3;

  int _index = 0;
  late final ProfileEditController _profileEditController;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _profileEditController = ProfileEditController();
    _pages = <Widget>[
      const HomeScreen(),
      const RoutePlannerScreen(),
      const DataScreen(),
      ProfileScreen(editController: _profileEditController),
    ];
  }

  @override
  void dispose() {
    _profileEditController.dispose();
    super.dispose();
  }

  Future<void> _selectDestination(int nextIndex) async {
    if (nextIndex == _index) return;

    final leavingDirtyProfile =
        _index == _profileIndex &&
        nextIndex != _profileIndex &&
        _profileEditController.isDirty;

    if (leavingDirtyProfile) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard profile changes?'),
          content: const Text(
            'You have unsaved profile changes. Leave without saving them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );

      if (!mounted || discard != true) return;
      _profileEditController.discardChanges();
    }

    if (!mounted) return;
    setState(() => _index = nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: 'Offline',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
