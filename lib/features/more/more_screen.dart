import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../about/about_screen.dart';
import '../alerts/alerts_screen.dart';
import '../rewards/rewards_screen.dart';
import '../rewards/rewards_store.dart';
import '../settings/travel_preferences_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  RewardsSnapshot? _rewards;

  @override
  void initState() {
    super.initState();
    RewardsStore.checkIn().then((value) { if (mounted) setState(() => _rewards = value); });
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) async {
      final rewards = await RewardsStore.load();
      if (mounted) setState(() => _rewards = rewards);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _rewards;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (rewards != null) ...[
            Card(child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(const RewardsScreen()),
              child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                const CircleAvatar(radius: 26, backgroundColor: Color(0x1400857C), child: Icon(Icons.emoji_events_outlined, color: AppTheme.signalTeal)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('XploreRewards · Level ${rewards.level}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${rewards.xp} XP · ${rewards.streak} day streak', style: const TextStyle(color: AppTheme.slate)),
                ])),
                const Icon(Icons.chevron_right),
              ])),
            )),
            const SizedBox(height: 16),
          ],
          _MenuCard(icon: Icons.notifications_active_outlined, title: 'Alerts Centre', subtitle: 'Data freshness and service notices', onTap: () => _open(const AlertsScreen())),
          _MenuCard(icon: Icons.tune_outlined, title: 'Travel Preferences', subtitle: 'Home, Work, walking and transfer preferences', onTap: () => _open(const TravelPreferencesScreen())),
          _MenuCard(icon: Icons.info_outline, title: 'About & Data Sources', subtitle: 'Official GTFS, realtime and map sources', onTap: () => _open(const AboutDataSourcesScreen())),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(icon, color: AppTheme.trackNavy),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        )),
      );
}
