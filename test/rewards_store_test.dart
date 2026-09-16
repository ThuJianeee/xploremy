import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/features/rewards/rewards_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RewardsStore.setUserId('user-a');
  });

  test('XP maps to level and progress', () {
    const snapshot = RewardsSnapshot(
      xp: 750,
      streak: 3,
      lastActiveDate: null,
      claimedRewards: <String>{},
    );
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
      'xplore_rewards_xp::user-a': 20,
      'xplore_rewards_streak::user-a': 2,
      'xplore_rewards_last_active::user-a': day,
    });

    final snapshot = await RewardsStore.checkIn();
    expect(snapshot.xp, 30);
    expect(snapshot.streak, 3);
  });

  test(
    'mission reward XP is granted once when the target is reached',
    () async {
      await RewardsStore.incrementMission('journey_planned', by: 2);
      expect((await RewardsStore.load()).xp, 0);

      await RewardsStore.incrementMission('journey_planned');
      expect((await RewardsStore.load()).xp, 60);

      await RewardsStore.incrementMission('journey_planned');
      expect((await RewardsStore.load()).xp, 60);
    },
  );

  test('completed mission labels match total XP', () async {
    await RewardsStore.checkIn();
    await RewardsStore.incrementMission('stop_opened', by: 5);
    await RewardsStore.incrementMission('data_sync', by: 3);
    expect((await RewardsStore.load()).xp, 100);
  });

  test('legacy per-action XP is normalized to mission completion XP', () async {
    SharedPreferences.setMockInitialValues({
      'xplore_rewards_xp::user-a': 25,
      'xplore_rewards_missions::user-a':
          '{"daily_checkin":1,"stop_opened":5,"data_sync":3}',
    });

    final snapshot = await RewardsStore.load();
    expect(snapshot.xp, 100);
  });

  test('claim deducts XP once', () async {
    SharedPreferences.setMockInitialValues({'xplore_rewards_xp::user-a': 600});
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

  test('reward progress is isolated between accounts', () async {
    await RewardsStore.addXp(90);
    await RewardsStore.incrementMission('journey_planned', by: 2);

    RewardsStore.setUserId('user-b');
    expect((await RewardsStore.load()).xp, 0);
    expect(await RewardsStore.missionProgress(), isEmpty);

    await RewardsStore.addXp(15);
    await RewardsStore.incrementMission('stop_opened');

    RewardsStore.setUserId('user-a');
    expect((await RewardsStore.load()).xp, 90);
    expect((await RewardsStore.missionProgress())['journey_planned'], 2);

    RewardsStore.setUserId('user-b');
    expect((await RewardsStore.load()).xp, 15);
    expect((await RewardsStore.missionProgress())['stop_opened'], 1);
  });

  test('legacy device-wide reward keys are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'xplore_rewards_xp': 999,
      'xplore_rewards_missions': '{"journey_planned":3}',
    });
    RewardsStore.setUserId('new-user');
    expect((await RewardsStore.load()).xp, 0);
    expect(await RewardsStore.missionProgress(), isEmpty);
  });
}
