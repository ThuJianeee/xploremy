import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/data/models.dart';
import 'package:xploremy/features/settings/travel_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('travel preferences and Home/Work round-trip', () async {
    const stop = GtfsStop(operatorId: 'rapid-rail-kl', stopId: 'A', name: 'Home Station', lat: 3.1, lon: 101.6);
    const home = PlannerStopOption(displayName: 'Home Station', operatorId: 'rapid-rail-kl', routeId: 'KJL', routeShortName: 'KJL', routeLongName: 'Kelana Jaya', routeType: 1, stops: [stop]);
    const value = TravelPreferences(preferFewerTransfers: true, preferRail: true, home: home);

    await TravelPreferencesStore.save(value);
    final loaded = await TravelPreferencesStore.load();

    expect(loaded.preferFewerTransfers, isTrue);
    expect(loaded.preferRail, isTrue);
    expect(loaded.home?.primaryStop.stopId, 'A');
    expect(loaded.home?.lineName, 'Kelana Jaya');
  });
}
