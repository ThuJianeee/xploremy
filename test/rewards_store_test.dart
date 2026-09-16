import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/features/rewards/rewards_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('XP maps to level and progress', () {
    const snapshot = RewardsSnapshot(
        xp: 750, streak: 3, lastActiveDate: null, claimedRewards: <String>{});
    expect(snapshot.level, 2);
    expect(snapshot.levelStartXp, 500);
    expect(snapshot.nextLevelXp, 1000);
    expect(snapshot.levelProgress, 0.5);
  });

  test('check-in continues a daily streak and grants XP', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final day =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'xplore_rewards_xp': 20,
      'xplore_rewards_streak': 2,
      'xplore_rewards_last_active': day,
    });

    final snapshot = await RewardsStore.checkIn();
    expect(snapshot.xp, 30);
    expect(snapshot.streak, 3);
  });

  test('claim deducts XP once', () async {
    SharedPreferences.setMockInitialValues({'xplore_rewards_xp': 600});
    expect(await RewardsStore.claim('eco', 500), isTrue);
    expect((await RewardsStore.load()).xp, 100);
    expect(await RewardsStore.claim('eco', 500), isFalse);
  });

  test('mission progress increments', () async {
    await RewardsStore.incrementMission('journey_planned');
    await RewardsStore.incrementMission('journey_planned', by: 2);
    final progress = await RewardsStore.missionProgress();
    expect(progress['journey_planned'], 3);
  });
}
