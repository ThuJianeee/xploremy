import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models.dart';

enum SavedAddressRole { home, work, other }

extension SavedAddressRoleLabel on SavedAddressRole {
  String get label {
    switch (this) {
      case SavedAddressRole.home:
        return 'Home';
      case SavedAddressRole.work:
        return 'Work';
      case SavedAddressRole.other:
        return 'Other';
    }
  }
}

class SavedAddressEntry {
  const SavedAddressEntry({
    required this.id,
    required this.label,
    required this.role,
    required this.stop,
    required this.createdAt,
  });

  final String id;
  final String label;
  final SavedAddressRole role;
  final PlannerStopOption stop;
  final DateTime createdAt;

  SavedAddressEntry copyWith({
    String? label,
    SavedAddressRole? role,
    PlannerStopOption? stop,
  }) {
    return SavedAddressEntry(
      id: id,
      label: label ?? this.label,
      role: role ?? this.role,
      stop: stop ?? this.stop,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'role': role.name,
        'stop': _encodeOption(stop),
        'created_at': createdAt.toIso8601String(),
      };

  factory SavedAddressEntry.fromMap(Map<String, dynamic> map) {
    final roleName = map['role'] as String? ?? 'other';
    final role = SavedAddressRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => SavedAddressRole.other,
    );
    final stop = _decodeOption(map['stop']);
    if (stop == null) {
      throw const FormatException('Saved address is missing a stop');
    }
    return SavedAddressEntry(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? 'Saved place',
      role: role,
      stop: stop,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SavedAddressStore {
  SavedAddressStore._();

  static String _key(String userId) => 'xploremy_saved_addresses_v1_$userId';

  static Future<List<SavedAddressEntry>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) => SavedAddressEntry.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<SavedAddressEntry>> upsert(
    String userId,
    SavedAddressEntry entry,
  ) async {
    final current = await load(userId);
    final normalized = current.map((item) {
      if (entry.role != SavedAddressRole.other &&
          item.id != entry.id &&
          item.role == entry.role) {
        return item.copyWith(role: SavedAddressRole.other);
      }
      return item;
    }).toList();

    final index = normalized.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      normalized.add(entry);
    } else {
      normalized[index] = entry;
    }
    await _write(userId, normalized);
    return normalized;
  }

  static Future<List<SavedAddressEntry>> delete(
    String userId,
    String id,
  ) async {
    final current = await load(userId);
    final updated = current.where((item) => item.id != id).toList();
    await _write(userId, updated);
    return updated;
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  static Future<void> _write(
    String userId,
    List<SavedAddressEntry> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode(values.map((item) => item.toMap()).toList()),
    );
  }
}

Map<String, dynamic> _encodeOption(PlannerStopOption option) => {
      'display_name': option.displayName,
      'operator_id': option.operatorId,
      'route_id': option.routeId,
      'route_short_name': option.routeShortName,
      'route_long_name': option.routeLongName,
      'route_type': option.routeType,
      'stops': option.stops.map((stop) => stop.toMap()).toList(),
    };

PlannerStopOption? _decodeOption(dynamic value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);
  final rawStops = map['stops'];
  if (rawStops is! List || rawStops.isEmpty) return null;
  final stops = rawStops
      .whereType<Map>()
      .map((item) => GtfsStop.fromMap(Map<String, Object?>.from(item)))
      .toList();
  if (stops.isEmpty) return null;
  return PlannerStopOption(
    displayName: map['display_name'] as String? ?? stops.first.name,
    operatorId: map['operator_id'] as String? ?? stops.first.operatorId,
    routeId: map['route_id'] as String? ?? '',
    routeShortName: map['route_short_name'] as String? ?? '',
    routeLongName: map['route_long_name'] as String? ?? '',
    routeType: (map['route_type'] as num?)?.toInt() ?? 3,
    stops: stops,
  );
}
