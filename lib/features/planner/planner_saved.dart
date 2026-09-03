import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'planner_history.dart';

class PlannerSavedStore {
  PlannerSavedStore._();

  static const _key = 'planner_saved_journeys';
  static const _limit = 12;

  static Future<List<PlannerHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_key) ?? const [];

    return rows
        .map((row) {
          try {
            final map = jsonDecode(row) as Map<String, dynamic>;
            return PlannerHistoryEntry.fromMap(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<PlannerHistoryEntry>()
        .toList();
  }

  static Future<List<PlannerHistoryEntry>> add(
    PlannerHistoryEntry entry,
  ) async {
    final current = await load();
    final updated = [
      entry,
      ...current.where((item) => item.key != entry.key),
    ].take(_limit).toList();

    await _write(updated);
    return updated;
  }

  static Future<List<PlannerHistoryEntry>> remove(String key) async {
    final current = await load();
    final updated = current.where((item) => item.key != key).toList();
    await _write(updated);
    return updated;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _write(List<PlannerHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((item) => jsonEncode(item.toMap())).toList(),
    );
  }
}
