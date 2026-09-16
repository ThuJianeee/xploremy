import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';

enum DefaultTransport { any, rail, bus }

extension DefaultTransportLabel on DefaultTransport {
  String get label {
    switch (this) {
      case DefaultTransport.any:
        return 'Any transport';
      case DefaultTransport.rail:
        return 'Rail';
      case DefaultTransport.bus:
        return 'Bus';
    }
  }
}

class TravelPreferences {
  const TravelPreferences({
    this.preferFewerTransfers = false,
    this.preferLessWalking = false,
    this.preferRail = false,
    this.accessibleMode = false,
    this.defaultTransport = DefaultTransport.any,
    this.home,
    this.work,
  });

  final bool preferFewerTransfers;
  final bool preferLessWalking;
  final bool preferRail;
  final bool accessibleMode;
  final DefaultTransport defaultTransport;
  final PlannerStopOption? home;
  final PlannerStopOption? work;

  TravelPreferences copyWith({
    bool? preferFewerTransfers,
    bool? preferLessWalking,
    bool? preferRail,
    bool? accessibleMode,
    DefaultTransport? defaultTransport,
    PlannerStopOption? home,
    PlannerStopOption? work,
    bool clearHome = false,
    bool clearWork = false,
  }) {
    return TravelPreferences(
      preferFewerTransfers: preferFewerTransfers ?? this.preferFewerTransfers,
      preferLessWalking: preferLessWalking ?? this.preferLessWalking,
      preferRail: preferRail ?? this.preferRail,
      accessibleMode: accessibleMode ?? this.accessibleMode,
      defaultTransport: defaultTransport ?? this.defaultTransport,
      home: clearHome ? null : (home ?? this.home),
      work: clearWork ? null : (work ?? this.work),
    );
  }
}

class TravelPreferencesStore {
  static const _key = 'xploremy_travel_preferences_v1';

  static Future<TravelPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const TravelPreferences();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final rawTransport = map['default_transport'] as String?;
      final transport = DefaultTransport.values.firstWhere(
        (value) => value.name == rawTransport,
        orElse: () => map['prefer_rail'] == true
            ? DefaultTransport.rail
            : DefaultTransport.any,
      );
      return TravelPreferences(
        preferFewerTransfers: map['prefer_fewer_transfers'] == true,
        preferLessWalking: map['prefer_less_walking'] == true,
        preferRail: map['prefer_rail'] == true,
        accessibleMode: map['accessible_mode'] == true,
        defaultTransport: transport,
        home: _decodeOption(map['home']),
        work: _decodeOption(map['work']),
      );
    } catch (_) {
      return const TravelPreferences();
    }
  }

  static Future<void> save(TravelPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'prefer_fewer_transfers': value.preferFewerTransfers,
          'prefer_less_walking': value.preferLessWalking,
          'prefer_rail': value.preferRail,
          'accessible_mode': value.accessibleMode,
          'default_transport': value.defaultTransport.name,
          'home': _encodeOption(value.home),
          'work': _encodeOption(value.work),
        }));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, dynamic>? _encodeOption(PlannerStopOption? option) {
    if (option == null) return null;
    return {
      'display_name': option.displayName,
      'operator_id': option.operatorId,
      'route_id': option.routeId,
      'route_short_name': option.routeShortName,
      'route_long_name': option.routeLongName,
      'route_type': option.routeType,
      'stops': option.stops.map((stop) => stop.toMap()).toList(),
    };
  }

  static PlannerStopOption? _decodeOption(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final rawStops = map['stops'];
    if (rawStops is! List || rawStops.isEmpty) return null;
    final stops = rawStops
        .map((item) => GtfsStop.fromMap(Map<String, Object?>.from(item as Map)))
        .toList();
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
}
