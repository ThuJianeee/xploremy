import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xploremy/features/profile/favorites/favorites_folder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('favorites folders support create rename item add/remove and delete',
      () async {
    const userId = 'user-1';

    var folders = await FavoritesFolderStore.create(userId, 'Daily Commute');
    expect(folders, hasLength(1));
    final folderId = folders.single.id;

    folders = await FavoritesFolderStore.rename(
      userId,
      folderId,
      'Campus Commute',
    );
    expect(folders.single.name, 'Campus Commute');

    folders = await FavoritesFolderStore.addItem(
      userId,
      folderId,
      const FavoriteFolderItem(
        id: 'stop:rapid:KLS',
        type: 'stop',
        title: 'KL Sentral',
        subtitle: 'Rapid KL',
        payload: {'operatorId': 'rapid', 'stopId': 'KLS'},
      ),
    );
    expect(folders.single.items, hasLength(1));

    folders = await FavoritesFolderStore.removeItem(
      userId,
      folderId,
      'stop:rapid:KLS',
    );
    expect(folders.single.items, isEmpty);

    folders = await FavoritesFolderStore.delete(userId, folderId);
    expect(folders, isEmpty);
  });
}
