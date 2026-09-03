import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

class PlannerHistoryEntry {
  const PlannerHistoryEntry({
    required this.fromName,
    required this.fromOperatorId,
    required this.fromRouteId,
    required this.toName,
    required this.toOperatorId,
    required this.toRouteId,
    required this.usedAt,
  });

  final String fromName;
  final String fromOperatorId;
  final String fromRouteId;
  final String toName;
  final String toOperatorId;
  final String toRouteId;
  final DateTime usedAt;

  factory PlannerHistoryEntry.fromOptions({
    required PlannerStopOption from,
    required PlannerStopOption to,
  }) {
    return PlannerHistoryEntry(
      fromName: from.displayName,
      fromOperatorId: from.operatorId,
      fromRouteId: from.routeId,
      toName: to.displayName,
      toOperatorId: to.operatorId,
      toRouteId: to.routeId,
      usedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
        'fromName': fromName,
        'fromOperatorId': fromOperatorId,
        'fromRouteId': fromRouteId,
        'toName': toName,
        'toOperatorId': toOperatorId,
        'toRouteId': toRouteId,
        'usedAt': usedAt.toIso8601String(),
      };

  factory PlannerHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PlannerHistoryEntry(
      fromName: map['fromName'] as String? ?? '',
      fromOperatorId: map['fromOperatorId'] as String? ?? '',
      fromRouteId: map['fromRouteId'] as String? ?? '',
      toName: map['toName'] as String? ?? '',
      toOperatorId: map['toOperatorId'] as String? ?? '',
      toRouteId: map['toRouteId'] as String? ?? '',
      usedAt: DateTime.tryParse(map['usedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get key =>
      '$fromOperatorId|$fromRouteId|$fromName>$toOperatorId|$toRouteId|$toName';
}

class PlannerHistoryStore {
  PlannerHistoryStore._();

  static const _key = 'planner_recent_journeys';
  static const _limit = 5;

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      updated.map((item) => jsonEncode(item.toMap())).toList(),
    );
    return updated;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
