import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'rewards_store.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  RewardsSnapshot? _snapshot;
  Map<String, int> _progress = const {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loadError = null);
    }
    try {
      final snapshot = await RewardsStore.checkIn();
      final progress = await RewardsStore.missionProgress();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _progress = progress;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    }
  }

  Future<void> _claim(String id, int cost) async {
    final ok = await RewardsStore.claim(id, cost);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Reward claimed.' : 'Not enough XP or reward already claimed.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('XploreRewards')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: AppTheme.hibiscus),
                      const SizedBox(height: 12),
                      const Text('Unable to load rewards.', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.slate, fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 130,
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    final badges = RewardsStore.badges(snapshot, _progress);
    final missions = RewardsStore.missions(_progress);
    return Scaffold(
      appBar: AppBar(title: const Text('XploreRewards')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Level ${snapshot.level}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                  Text('${snapshot.xp} XP', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.signalTeal)),
                ]),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: snapshot.levelProgress),
                const SizedBox(height: 8),
                Text('${snapshot.nextLevelXp - snapshot.xp} XP to next level · ${snapshot.streak} day streak 🔥', style: const TextStyle(color: AppTheme.slate)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final badge in badges)
              SizedBox(width: 165, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(badge.icon, style: TextStyle(fontSize: 30, color: badge.unlocked ? null : Colors.grey)),
                const SizedBox(height: 8),
                Text(badge.title, style: TextStyle(fontWeight: FontWeight.w700, color: badge.unlocked ? null : AppTheme.slate)),
                Text(badge.description, style: const TextStyle(fontSize: 12, color: AppTheme.slate)),
              ])))),
          ]),
          const SizedBox(height: 22),
          const Text('Missions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final mission in missions)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(
              leading: Icon(mission.completed ? Icons.check_circle : Icons.flag_outlined, color: mission.completed ? AppTheme.onTime : AppTheme.trackNavy),
              title: Text(mission.title),
              subtitle: Text('${mission.progress.clamp(0, mission.target)}/${mission.target} · +${mission.xp} XP'),
              trailing: SizedBox(width: 70, child: LinearProgressIndicator(value: (mission.progress / mission.target).clamp(0.0, 1.0).toDouble())),
            ))),
          const SizedBox(height: 12),
          const Text('Rewards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _RewardTile(title: 'Transit Explorer Theme Badge', cost: 250, claimed: snapshot.claimedRewards.contains('theme_badge'), onClaim: () => _claim('theme_badge', 250)),
          _RewardTile(title: 'Eco Commuter Profile Flair', cost: 500, claimed: snapshot.claimedRewards.contains('eco_flair'), onClaim: () => _claim('eco_flair', 500)),
          const Padding(padding: EdgeInsets.only(top: 10), child: Text('Rewards are in-app achievements only and have no cash value.', style: TextStyle(fontSize: 11.5, color: AppTheme.slate))),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.title, required this.cost, required this.claimed, required this.onClaim});
  final String title;
  final int cost;
  final bool claimed;
  final VoidCallback onClaim;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(child: ListTile(
          leading: const Icon(Icons.card_giftcard_outlined, color: AppTheme.hibiscus),
          title: Text(title),
          subtitle: Text('$cost XP'),
          trailing: SizedBox(
            width: 96,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(96, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: claimed ? null : onClaim,
              child: Text(claimed ? 'Claimed' : 'Claim'),
            ),
          ),
        )),
      );
}
