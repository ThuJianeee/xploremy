import 'package:flutter/material.dart';

import '../data_sync/data_screen.dart';
import '../home/home_screen.dart';
import '../planner/route_planner_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
  });

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    RoutePlannerScreen(),
    DataScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.near_me_outlined,
            ),
            selectedIcon: Icon(
              Icons.near_me,
            ),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.route_outlined,
            ),
            selectedIcon: Icon(
              Icons.route,
            ),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.cloud_download_outlined,
            ),
            selectedIcon: Icon(
              Icons.cloud_download,
            ),
            label: 'Offline',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
