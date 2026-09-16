import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteFolderItem {
  const FavoriteFolderItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'payload': payload,
      };

  factory FavoriteFolderItem.fromMap(Map<String, dynamic> map) {
    return FavoriteFolderItem(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'stop',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      payload: Map<String, dynamic>.from(
        (map['payload'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<FavoriteFolderItem> items;

  FavoriteFolder copyWith({
    String? name,
    List<FavoriteFolderItem>? items,
  }) {
    return FavoriteFolder(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((item) => item.toMap()).toList(),
      };

  factory FavoriteFolder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List? ?? const [];
    return FavoriteFolder(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Favorites',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      items: rawItems
          .whereType<Map>()
          .map((item) => FavoriteFolderItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class FavoritesFolderStore {
  FavoritesFolderStore._();

  static String _key(String userId) => 'profile_favorite_folders_v1_$userId';

  static Future<List<FavoriteFolder>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) => FavoriteFolder.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<FavoriteFolder>> create(
    String userId,
    String name,
  ) async {
    final current = await load(userId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) return current;

    final folder = FavoriteFolder(
      id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: DateTime.now(),
      items: const [],
    );
    final updated = [...current, folder];
    await _write(userId, updated);
    return updated;
  }

  static Future<List<FavoriteFolder>> rename(
    String userId,
    String folderId,
    String name,
  ) async {
    final current = await load(userId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) return current;
    final updated = current
        .map((folder) =>
            folder.id == folderId ? folder.copyWith(name: trimmed) : folder)
        .toList();
    await _write(userId, updated);
    return updated;
  }

  static Future<List<FavoriteFolder>> delete(
    String userId,
    String folderId,
  ) async {
    final current = await load(userId);
    final updated = current.where((folder) => folder.id != folderId).toList();
    await _write(userId, updated);
    return updated;
  }

  static Future<List<FavoriteFolder>> addItem(
    String userId,
    String folderId,
    FavoriteFolderItem item,
  ) async {
    final current = await load(userId);
    final updated = current.map((folder) {
      if (folder.id != folderId) return folder;
      final items = [
        ...folder.items.where((existing) => existing.id != item.id),
        item,
      ];
      return folder.copyWith(items: items);
    }).toList();
    await _write(userId, updated);
    return updated;
  }

  static Future<List<FavoriteFolder>> removeItem(
    String userId,
    String folderId,
    String itemId,
  ) async {
    final current = await load(userId);
    final updated = current.map((folder) {
      if (folder.id != folderId) return folder;
      return folder.copyWith(
        items: folder.items.where((item) => item.id != itemId).toList(),
      );
    }).toList();
    await _write(userId, updated);
    return updated;
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> _write(
    String userId,
    List<FavoriteFolder> folders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode(folders.map((folder) => folder.toMap()).toList()),
    );
  }
}
