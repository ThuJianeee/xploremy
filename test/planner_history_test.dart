import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/data/models.dart';
import 'package:xploremy/features/planner/planner_history.dart';
import 'package:xploremy/features/planner/planner_saved.dart';

PlannerStopOption option(String name, String routeId) => PlannerStopOption(
      displayName: name,
      operatorId: 'rapid-rail-kl',
      routeId: routeId,
      routeShortName: routeId,
      routeLongName: routeId,
      routeType: 1,
      stops: [
        GtfsStop(
          operatorId: 'rapid-rail-kl',
          stopId: '$routeId-$name',
          name: name,
          lat: 3,
          lon: 101,
        ),
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recent journey is stored and loaded', () async {
    final entry = PlannerHistoryEntry.fromOptions(
      from: option('KL Sentral', 'KJL'),
      to: option('KLCC', 'KJL'),
    );

    await PlannerHistoryStore.add(entry);
    final loaded = await PlannerHistoryStore.load();

    expect(loaded, hasLength(1));
    expect(loaded.first.fromName, 'KL Sentral');
    expect(loaded.first.toName, 'KLCC');
  });

  test('duplicate journey is kept only once', () async {
    final entry = PlannerHistoryEntry.fromOptions(
      from: option('KL Sentral', 'KJL'),
      to: option('KLCC', 'KJL'),
    );

    await PlannerHistoryStore.add(entry);
    await PlannerHistoryStore.add(entry);

    expect(await PlannerHistoryStore.load(), hasLength(1));
  });

  test('saved journey is stored and removed locally', () async {
    final entry = PlannerHistoryEntry.fromOptions(
      from: option('KL Sentral', 'KJL'),
      to: option('Bukit Bintang', 'MRL'),
    );

    final saved = await PlannerSavedStore.add(entry);
    expect(saved, hasLength(1));
    expect((await PlannerSavedStore.load()).first.toName, 'Bukit Bintang');

    final removed = await PlannerSavedStore.remove(entry.key);
    expect(removed, isEmpty);
    expect(await PlannerSavedStore.load(), isEmpty);
  });

  test('saved journey does not duplicate the same route', () async {
    final entry = PlannerHistoryEntry.fromOptions(
      from: option('KL Sentral', 'KJL'),
      to: option('KLCC', 'KJL'),
    );

    await PlannerSavedStore.add(entry);
    await PlannerSavedStore.add(entry);

    expect(await PlannerSavedStore.load(), hasLength(1));
  });

}
