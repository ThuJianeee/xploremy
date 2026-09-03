part of '../local_store.dart';

extension LocalGtfsPlannerStore on LocalGtfsStore {
  String _normalisePlannerStationName(
    String value,
  ) {
    var name = value.trim();

    name = name.replaceAll(
      RegExp(
        r'\s*-\s*REDONE\s*$',
        caseSensitive: false,
      ),
      '',
    );

    name = name.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return name.toUpperCase();
  }

  String _displayPlannerStationName(
    String value,
  ) {
    var name = value.trim();

    name = name.replaceAll(
      RegExp(
        r'\s*-\s*REDONE\s*$',
        caseSensitive: false,
      ),
      '',
    );

    name = name.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return name.isEmpty ? value : name;
  }

  Future<List<PlannerStopOption>> searchPlannerStops(
    String query, {
    int limit = 40,
  }) async {
    final db = await database;

    final clean = query.trim();

    if (clean.length < 2) {
      return const [];
    }

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT
        s.operator_id,
        s.stop_id,
        s.name,
        s.lat,
        s.lon,
        r.route_id,
        r.short_name,
        r.long_name,
        r.type

      FROM stops s

      JOIN stop_times st
        ON st.operator_id = s.operator_id
        AND st.stop_id = s.stop_id

      JOIN trips t
        ON t.operator_id = st.operator_id
        AND t.trip_id = st.trip_id

      JOIN routes r
        ON r.operator_id = t.operator_id
        AND r.route_id = t.route_id

      WHERE s.name LIKE ?

      ORDER BY
        s.name COLLATE NOCASE ASC,
        r.long_name COLLATE NOCASE ASC,
        r.short_name COLLATE NOCASE ASC

      LIMIT 500
      ''',
      [
        '%$clean%',
      ],
    );

    return _groupPlannerRows(
      rows,
      limit: limit,
    );
  }

  Future<List<PlannerStopOption>> plannerOptionsForStop({
    required String operatorId,
    required String stopId,
  }) async {
    final selected = await LocalGtfsStopStore(this).stopById(
      operatorId,
      stopId,
    );

    if (selected == null) {
      return const [];
    }

    final searchName = _displayPlannerStationName(
      selected.name,
    );

    final options = await searchPlannerStops(
      searchName,
      limit: 80,
    );

    final exactMatches = options.where(
      (option) {
        if (option.operatorId != operatorId) {
          return false;
        }

        return option.stops.any(
          (stop) => stop.stopId == stopId && stop.operatorId == operatorId,
        );
      },
    ).toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    final stationKey = _normalisePlannerStationName(
      selected.name,
    );

    return options.where(
      (option) {
        return option.operatorId == operatorId &&
            _normalisePlannerStationName(
                  option.displayName,
                ) ==
                stationKey;
      },
    ).toList();
  }

  List<PlannerStopOption> _groupPlannerRows(
    List<Map<String, Object?>> rows, {
    required int limit,
  }) {
    final grouped = <String, _PlannerGroup>{};

    for (final row in rows) {
      final operatorId = row['operator_id'] as String;

      final stopId = row['stop_id'] as String;

      final stopName = row['name'] as String;

      final routeId = (row['route_id'] as String?) ?? '';

      if (routeId.isEmpty) {
        continue;
      }

      final shortName = (row['short_name'] as String?) ?? '';

      final longName = (row['long_name'] as String?) ?? '';

      final routeType = (row['type'] as num?)?.toInt() ?? 3;

      final stationKey = _normalisePlannerStationName(
        stopName,
      );

      final groupKey = '$operatorId|$routeId|$stationKey';

      final stop = GtfsStop(
        operatorId: operatorId,
        stopId: stopId,
        name: stopName,
        lat: (row['lat'] as num).toDouble(),
        lon: (row['lon'] as num).toDouble(),
      );

      final group = grouped.putIfAbsent(
        groupKey,
        () => _PlannerGroup(
          displayName: _displayPlannerStationName(
            stopName,
          ),
          operatorId: operatorId,
          routeId: routeId,
          routeShortName: shortName,
          routeLongName: longName,
          routeType: routeType,
        ),
      );

      final alreadyAdded = group.stops.any(
        (existing) =>
            existing.operatorId == stop.operatorId &&
            existing.stopId == stop.stopId,
      );

      if (!alreadyAdded) {
        group.stops.add(stop);
      }
    }

    final options = grouped.values
        .where(
          (group) => group.stops.isNotEmpty,
        )
        .map(
          (group) => PlannerStopOption(
            displayName: group.displayName,
            operatorId: group.operatorId,
            routeId: group.routeId,
            routeShortName: group.routeShortName,
            routeLongName: group.routeLongName,
            routeType: group.routeType,
            stops: List.unmodifiable(group.stops),
          ),
        )
        .toList();

    options.sort(
      (a, b) {
        final stationCompare = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );

        if (stationCompare != 0) {
          return stationCompare;
        }

        return a.lineName.toLowerCase().compareTo(
              b.lineName.toLowerCase(),
            );
      },
    );

    return options.take(limit).toList();
  }

  // ==============================================================
  // SERVICE CALENDAR
  // ==============================================================

}

class _PlannerGroup {
  _PlannerGroup({
    required this.displayName,
    required this.operatorId,
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeType,
  });

  final String displayName;
  final String operatorId;
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final int routeType;

  final List<GtfsStop> stops = [];
}
