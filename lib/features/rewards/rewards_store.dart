import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RewardBadge {
  const RewardBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
}

class MissionProgress {
  const MissionProgress({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.xp,
  });
  final String id;
  final String title;
  final int target;
  final int progress;
  final int xp;
  bool get completed => progress >= target;
}

class RewardsSnapshot {
  const RewardsSnapshot({
    required this.xp,
    required this.streak,
    required this.lastActiveDate,
    required this.claimedRewards,
  });
  final int xp;
  final int streak;
  final String? lastActiveDate;
  final Set<String> claimedRewards;

  int get level => xp ~/ 500 + 1;
  int get levelStartXp => (level - 1) * 500;
  int get nextLevelXp => level * 500;
  double get levelProgress =>
      ((xp - levelStartXp) / 500).clamp(0.0, 1.0).toDouble();
}

class RewardsStore {
  static const _xpKey = 'xplore_rewards_xp';
  static const _streakKey = 'xplore_rewards_streak';
  static const _lastActiveKey = 'xplore_rewards_last_active';
  static const _missionsKey = 'xplore_rewards_missions';
  static const _claimedKey = 'xplore_rewards_claimed';
  static const _awardedMissionRewardsKey =
      'xplore_rewards_awarded_mission_rewards';
  static const _xpModelVersionKey = 'xplore_rewards_xp_model_version';
  static const _xpModelVersion = 2;
  static const _missionTargets = <String, int>{
    'journey_planned': 3,
    'stop_opened': 5,
    'data_sync': 3,
  };
  static const _missionRewardXp = <String, int>{
    'journey_planned': 60,
    'stop_opened': 50,
    'data_sync': 40,
  };
  static String? _userId;

  static void setUserId(String? userId) {
    final value = userId?.trim();
    _userId = value == null || value.isEmpty ? null : value;
  }

  static String _scopedKey(String base, {String? userId}) {
    final value = (userId ?? _userId)?.trim();
    final scope = value == null || value.isEmpty ? 'guest' : value;
    return '$base::$scope';
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, int> _decodeProgress(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, int>{};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  static Future<void> _migrateXpModel({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final versionKey = _scopedKey(_xpModelVersionKey, userId: userId);
    if ((prefs.getInt(versionKey) ?? 0) >= _xpModelVersion) {
      return;
    }

    final progress = _decodeProgress(
      prefs.getString(_scopedKey(_missionsKey, userId: userId)),
    );
    final hasLegacyActionProgress = (progress['journey_planned'] ?? 0) > 0 ||
        (progress['stop_opened'] ?? 0) > 0 ||
        (progress['data_sync'] ?? 0) > 0;

    final awarded = <String>{};
    var completionBonus = 0;
    for (final entry in _missionTargets.entries) {
      if ((progress[entry.key] ?? 0) >= entry.value) {
        awarded.add(entry.key);
        completionBonus += _missionRewardXp[entry.key] ?? 0;
      }
    }

    if (hasLegacyActionProgress) {
      final xpKey = _scopedKey(_xpKey, userId: userId);
      final currentXp = prefs.getInt(xpKey) ?? 0;
      final legacyActionXp = (progress['journey_planned'] ?? 0) * 5 +
          (progress['data_sync'] ?? 0) * 5;
      final normalizedXp = (currentXp - legacyActionXp + completionBonus)
          .clamp(0, 1 << 31)
          .toInt();
      await prefs.setInt(xpKey, normalizedXp);
    }

    await prefs.setStringList(
      _scopedKey(_awardedMissionRewardsKey, userId: userId),
      awarded.toList(),
    );
    await prefs.setInt(versionKey, _xpModelVersion);
  }

  static Future<RewardsSnapshot> load({String? userId}) async {
    await _migrateXpModel(userId: userId);
    final prefs = await SharedPreferences.getInstance();
    return RewardsSnapshot(
      xp: prefs.getInt(_scopedKey(_xpKey, userId: userId)) ?? 0,
      streak: prefs.getInt(_scopedKey(_streakKey, userId: userId)) ?? 0,
      lastActiveDate: prefs.getString(
        _scopedKey(_lastActiveKey, userId: userId),
      ),
      claimedRewards:
          (prefs.getStringList(_scopedKey(_claimedKey, userId: userId)) ??
                  const <String>[])
              .toSet(),
    );
  }

  static Future<RewardsSnapshot> checkIn() async {
    final userId = _userId;
    await _migrateXpModel(userId: userId);
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayKey(now);
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
    final lastActiveKey = _scopedKey(_lastActiveKey, userId: userId);
    final streakKey = _scopedKey(_streakKey, userId: userId);
    final xpKey = _scopedKey(_xpKey, userId: userId);
    final last = prefs.getString(lastActiveKey);
    var streak = prefs.getInt(streakKey) ?? 0;
    var xp = prefs.getInt(xpKey) ?? 0;
    if (last != today) {
      streak = last == yesterday ? streak + 1 : 1;
      xp += 10;
      await prefs.setInt(streakKey, streak);
      await prefs.setInt(xpKey, xp);
      await prefs.setString(lastActiveKey, today);
      await incrementMission('daily_checkin', userId: userId);
    }
    return load(userId: userId);
  }

  static Future<void> addXp(int amount, {String? userId}) async {
    if (amount <= 0) {
      return;
    }
    await _migrateXpModel(userId: userId);
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_xpKey, userId: userId);
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + amount);
  }

  static Future<Map<String, int>> missionProgress({String? userId}) async {
    await _migrateXpModel(userId: userId);
    final prefs = await SharedPreferences.getInstance();
    return _decodeProgress(
      prefs.getString(_scopedKey(_missionsKey, userId: userId)),
    );
  }

  static Future<void> incrementMission(
    String id, {
    int by = 1,
    String? userId,
  }) async {
    final scopedUserId = userId ?? _userId;
    await _migrateXpModel(userId: scopedUserId);
    final prefs = await SharedPreferences.getInstance();
    final missionsKey = _scopedKey(_missionsKey, userId: scopedUserId);
    final progress = _decodeProgress(prefs.getString(missionsKey));
    final before = progress[id] ?? 0;
    final after = before + by;
    progress[id] = after;
    await prefs.setString(missionsKey, jsonEncode(progress));

    final target = _missionTargets[id];
    final rewardXp = _missionRewardXp[id];
    if (target == null ||
        rewardXp == null ||
        before >= target ||
        after < target) {
      return;
    }

    final awardedKey = _scopedKey(
      _awardedMissionRewardsKey,
      userId: scopedUserId,
    );
    final awarded =
        (prefs.getStringList(awardedKey) ?? const <String>[]).toSet();
    if (awarded.contains(id)) {
      return;
    }

    awarded.add(id);
    await prefs.setStringList(awardedKey, awarded.toList());
    final xpKey = _scopedKey(_xpKey, userId: scopedUserId);
    await prefs.setInt(xpKey, (prefs.getInt(xpKey) ?? 0) + rewardXp);
  }

  static Future<void> clear({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_xpKey, userId: userId));
    await prefs.remove(_scopedKey(_streakKey, userId: userId));
    await prefs.remove(_scopedKey(_lastActiveKey, userId: userId));
    await prefs.remove(_scopedKey(_missionsKey, userId: userId));
    await prefs.remove(_scopedKey(_claimedKey, userId: userId));
    await prefs.remove(_scopedKey(_awardedMissionRewardsKey, userId: userId));
    await prefs.remove(_scopedKey(_xpModelVersionKey, userId: userId));
  }

  static Future<bool> claim(String id, int costXp) async {
    final userId = _userId;
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await load(userId: userId);
    if (snapshot.claimedRewards.contains(id) || snapshot.xp < costXp) {
      return false;
    }
    final claimed = {...snapshot.claimedRewards, id};
    await prefs.setInt(
      _scopedKey(_xpKey, userId: userId),
      snapshot.xp - costXp,
    );
    await prefs.setStringList(
      _scopedKey(_claimedKey, userId: userId),
      claimed.toList(),
    );
    return true;
  }

  static List<RewardBadge> badges(
    RewardsSnapshot snapshot,
    Map<String, int> progress,
  ) =>
      <RewardBadge>[
        RewardBadge(
          id: 'first_trip',
          title: 'First Ride',
          description: 'Plan your first journey',
          icon: '🚆',
          unlocked: (progress['journey_planned'] ?? 0) >= 1,
        ),
        RewardBadge(
          id: 'explorer',
          title: 'Explorer',
          description: 'Open 5 different stops',
          icon: '🧭',
          unlocked: (progress['stop_opened'] ?? 0) >= 5,
        ),
        RewardBadge(
          id: 'week_streak',
          title: '7-Day Streak',
          description: 'Check in for 7 days',
          icon: '🔥',
          unlocked: snapshot.streak >= 7,
        ),
        RewardBadge(
          id: 'offline_ready',
          title: 'Offline Ready',
          description: 'Refresh transport data 3 times',
          icon: '📦',
          unlocked: (progress['data_sync'] ?? 0) >= 3,
        ),
      ];

  static List<MissionProgress> missions(Map<String, int> progress) =>
      <MissionProgress>[
        MissionProgress(
          id: 'daily_checkin',
          title: 'Daily check-in',
          target: 1,
          progress: progress['daily_checkin'] ?? 0,
          xp: 10,
        ),
        MissionProgress(
          id: 'journey_planned',
          title: 'Plan 3 journeys',
          target: 3,
          progress: progress['journey_planned'] ?? 0,
          xp: 60,
        ),
        MissionProgress(
          id: 'stop_opened',
          title: 'Explore 5 stops',
          target: 5,
          progress: progress['stop_opened'] ?? 0,
          xp: 50,
        ),
        MissionProgress(
          id: 'data_sync',
          title: 'Keep data fresh',
          target: 3,
          progress: progress['data_sync'] ?? 0,
          xp: 40,
        ),
      ];
}
