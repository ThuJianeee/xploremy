import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/data/models.dart';
import 'package:xploremy/features/profile/settings/notification_preferences.dart';
import 'package:xploremy/features/profile/settings/saved_addresses.dart';
import 'package:xploremy/features/settings/travel_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const stop = GtfsStop(
    operatorId: 'rapid-rail-kl',
    stopId: 'KLS',
    name: 'KL Sentral',
    lat: 3.134,
    lon: 101.686,
  );
  const option = PlannerStopOption(
    displayName: 'KL Sentral',
    operatorId: 'rapid-rail-kl',
    routeId: 'KJL',
    routeShortName: 'KJL',
    routeLongName: 'Kelana Jaya Line',
    routeType: 1,
    stops: [stop],
  );

  test('saved addresses support create/update/delete with one Home role',
      () async {
    const userId = 'user-1';
    final first = SavedAddressEntry(
      id: 'a1',
      label: 'My Home',
      role: SavedAddressRole.home,
      stop: option,
      createdAt: DateTime(2026, 1, 1),
    );
    var items = await SavedAddressStore.upsert(userId, first);
    expect(items, hasLength(1));
    expect(items.single.role, SavedAddressRole.home);

    final second = SavedAddressEntry(
      id: 'a2',
      label: 'New Home',
      role: SavedAddressRole.home,
      stop: option,
      createdAt: DateTime(2026, 1, 2),
    );
    items = await SavedAddressStore.upsert(userId, second);
    expect(items, hasLength(2));
    expect(items.where((item) => item.role == SavedAddressRole.home),
        hasLength(1));
    expect(items.firstWhere((item) => item.id == 'a1').role,
        SavedAddressRole.other);

    items = await SavedAddressStore.delete(userId, 'a2');
    expect(items, hasLength(1));
  });

  test('notification management persists category toggles and lead time',
      () async {
    const userId = 'user-1';
    const value = NotificationPreferences(
      serviceAlerts: false,
      journeyReminders: true,
      departureReminders: false,
      rewardUpdates: false,
      dataFreshnessAlerts: true,
      reminderLeadMinutes: 15,
    );
    await NotificationPreferencesStore.save(userId, value);
    final loaded = await NotificationPreferencesStore.load(userId);
    expect(loaded.serviceAlerts, isFalse);
    expect(loaded.departureReminders, isFalse);
    expect(loaded.reminderLeadMinutes, 15);
  });

  test('default transport preference persists', () async {
    const value = TravelPreferences(defaultTransport: DefaultTransport.bus);
    await TravelPreferencesStore.save(value);
    final loaded = await TravelPreferencesStore.load();
    expect(loaded.defaultTransport, DefaultTransport.bus);
  });
}
