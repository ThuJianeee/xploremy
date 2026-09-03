import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart'
    hide VehiclePosition;
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/geo.dart';
import 'models.dart';

/// Data/API layer for Malaysia's official data.gov.my GTFS endpoints.
class GtfsApi {
  GtfsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GtfsStaticFeed> fetchStaticFeed(Operator op) async {
    final response = await _client
        .get(op.staticUrl)
        .timeout(AppConfig.networkTimeout);
    if (response.statusCode != 200) {
      throw GtfsException(
        'GTFS-static request for ${op.shortName} failed '
        '(HTTP ${response.statusCode})',
      );
    }
    return parseStaticArchive(op, response.bodyBytes);
  }

  /// Parses the files needed for correct service-day and frequency-aware
  /// departures. Rapid Rail relies heavily on frequencies.txt, so ignoring it
  /// produces the old 06:00/06:26-only timetable bug.
  GtfsStaticFeed parseStaticArchive(Operator op, Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    List<List<dynamic>> read(String name) {
      final file = archive.files.firstWhere(
        (f) => f.isFile && f.name.split('/').last == name,
        orElse: () => ArchiveFile(name, 0, <int>[]),
      );
      if (file.size == 0) return const [];
      final text = utf8.decode(file.content as List<int>, allowMalformed: true);
      return const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(text.replaceAll('\r\n', '\n'));
    }

    return GtfsStaticFeed(
      operatorId: op.id,
      stops: _parseStops(op, read('stops.txt')),
      routes: _parseRoutes(op, read('routes.txt')),
      trips: _parseTrips(op, read('trips.txt')),
      stopTimes: _parseStopTimes(op, read('stop_times.txt')),
      calendar: _parseCalendar(op, read('calendar.txt')),
      calendarDates: _parseCalendarDates(op, read('calendar_dates.txt')),
      frequencies: _parseFrequencies(op, read('frequencies.txt')),
      fetchedAt: DateTime.now(),
    );
  }

  /// data.gov.my currently exposes GTFS-RT vehicle positions. The official
  /// feed is refreshed every ~30 seconds for supported operators.
  Future<List<VehiclePosition>> fetchVehiclePositions(Operator op) async {
    final url = op.realtimeUrl;
    if (url == null) return const [];

    final response = await _client
        .get(url)
        .timeout(AppConfig.networkTimeout);
    if (response.statusCode != 200) {
      throw GtfsException(
        'GTFS-realtime request for ${op.shortName} failed '
        '(HTTP ${response.statusCode})',
      );
    }

    final message = FeedMessage.fromBuffer(response.bodyBytes);
    final result = <VehiclePosition>[];
    for (final entity in message.entity) {
      if (!entity.hasVehicle()) continue;
      final v = entity.vehicle;
      if (!v.hasPosition()) continue;
      result.add(
        VehiclePosition(
          operatorId: op.id,
          vehicleId: v.hasVehicle() && v.vehicle.hasId()
              ? v.vehicle.id
              : entity.id,
          lat: v.position.latitude.toDouble(),
          lon: v.position.longitude.toDouble(),
          tripId: v.hasTrip() && v.trip.hasTripId() ? v.trip.tripId : null,
          routeId: v.hasTrip() && v.trip.hasRouteId() ? v.trip.routeId : null,
          bearing:
              v.position.hasBearing() ? v.position.bearing.toDouble() : null,
          timestamp: v.hasTimestamp()
              ? DateTime.fromMillisecondsSinceEpoch(v.timestamp.toInt() * 1000)
              : null,
        ),
      );
    }
    return result;
  }

  Map<String, int> _header(List<dynamic> row) {
    final map = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      map[row[i].toString().trim().replaceAll('\uFEFF', '')] = i;
    }
    return map;
  }

  String _cell(List<dynamic> row, Map<String, int> h, String key) {
    final index = h[key];
    if (index == null || index >= row.length) return '';
    return row[index].toString().trim();
  }

  int? _dateKey(String value) {
    final compact = value.replaceAll('-', '').trim();
    if (compact.length != 8) return null;
    return int.tryParse(compact);
  }

  List<GtfsStop> _parseStops(Operator op, List<List<dynamic>> rows) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsStop>[];
    for (final row in rows.skip(1)) {
      final lat = double.tryParse(_cell(row, h, 'stop_lat'));
      final lon = double.tryParse(_cell(row, h, 'stop_lon'));
      final id = _cell(row, h, 'stop_id');
      if (lat == null || lon == null || id.isEmpty) continue;
      out.add(GtfsStop(
        operatorId: op.id,
        stopId: id,
        name: _cell(row, h, 'stop_name'),
        lat: lat,
        lon: lon,
      ));
    }
    return out;
  }

  List<GtfsRoute> _parseRoutes(Operator op, List<List<dynamic>> rows) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsRoute>[];
    for (final row in rows.skip(1)) {
      final id = _cell(row, h, 'route_id');
      if (id.isEmpty) continue;
      out.add(GtfsRoute(
        operatorId: op.id,
        routeId: id,
        shortName: _cell(row, h, 'route_short_name'),
        longName: _cell(row, h, 'route_long_name'),
        type: int.tryParse(_cell(row, h, 'route_type')) ?? 3,
        colorHex: _cell(row, h, 'route_color').isEmpty
            ? null
            : _cell(row, h, 'route_color'),
      ));
    }
    return out;
  }

  List<GtfsTrip> _parseTrips(Operator op, List<List<dynamic>> rows) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsTrip>[];
    for (final row in rows.skip(1)) {
      final id = _cell(row, h, 'trip_id');
      if (id.isEmpty) continue;
      out.add(GtfsTrip(
        operatorId: op.id,
        tripId: id,
        routeId: _cell(row, h, 'route_id'),
        serviceId: _cell(row, h, 'service_id'),
        headsign: _cell(row, h, 'trip_headsign'),
      ));
    }
    return out;
  }

  List<GtfsStopTime> _parseStopTimes(Operator op, List<List<dynamic>> rows) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsStopTime>[];
    for (final row in rows.skip(1)) {
      final tripId = _cell(row, h, 'trip_id');
      final stopId = _cell(row, h, 'stop_id');
      if (tripId.isEmpty || stopId.isEmpty) continue;
      final departure = parseGtfsTime(_cell(row, h, 'departure_time')) ??
          parseGtfsTime(_cell(row, h, 'arrival_time'));
      if (departure == null) continue;
      out.add(GtfsStopTime(
        operatorId: op.id,
        tripId: tripId,
        stopId: stopId,
        departureSeconds: departure,
        sequence: int.tryParse(_cell(row, h, 'stop_sequence')) ?? 0,
      ));
    }
    return out;
  }

  List<GtfsCalendarService> _parseCalendar(
    Operator op,
    List<List<dynamic>> rows,
  ) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsCalendarService>[];
    for (final row in rows.skip(1)) {
      final serviceId = _cell(row, h, 'service_id');
      final startDate = _dateKey(_cell(row, h, 'start_date'));
      final endDate = _dateKey(_cell(row, h, 'end_date'));
      if (serviceId.isEmpty || startDate == null || endDate == null) continue;
      bool active(String key) => _cell(row, h, key) == '1';
      out.add(GtfsCalendarService(
        operatorId: op.id,
        serviceId: serviceId,
        monday: active('monday'),
        tuesday: active('tuesday'),
        wednesday: active('wednesday'),
        thursday: active('thursday'),
        friday: active('friday'),
        saturday: active('saturday'),
        sunday: active('sunday'),
        startDate: startDate,
        endDate: endDate,
      ));
    }
    return out;
  }

  List<GtfsCalendarDate> _parseCalendarDates(
    Operator op,
    List<List<dynamic>> rows,
  ) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsCalendarDate>[];
    for (final row in rows.skip(1)) {
      final serviceId = _cell(row, h, 'service_id');
      final date = _dateKey(_cell(row, h, 'date'));
      final type = int.tryParse(_cell(row, h, 'exception_type'));
      if (serviceId.isEmpty || date == null || (type != 1 && type != 2)) {
        continue;
      }
      out.add(GtfsCalendarDate(
        operatorId: op.id,
        serviceId: serviceId,
        date: date,
        exceptionType: type!,
      ));
    }
    return out;
  }

  List<GtfsFrequency> _parseFrequencies(
    Operator op,
    List<List<dynamic>> rows,
  ) {
    if (rows.length < 2) return const [];
    final h = _header(rows.first);
    final out = <GtfsFrequency>[];
    for (final row in rows.skip(1)) {
      final tripId = _cell(row, h, 'trip_id');
      final start = parseGtfsTime(_cell(row, h, 'start_time'));
      final end = parseGtfsTime(_cell(row, h, 'end_time'));
      final headway = int.tryParse(_cell(row, h, 'headway_secs'));
      if (tripId.isEmpty ||
          start == null ||
          end == null ||
          headway == null ||
          headway <= 0 ||
          end <= start) {
        continue;
      }
      out.add(GtfsFrequency(
        operatorId: op.id,
        tripId: tripId,
        startSeconds: start,
        endSeconds: end,
        headwaySeconds: headway,
        exactTimes: _cell(row, h, 'exact_times') == '1',
      ));
    }
    return out;
  }
}

class GtfsStaticFeed {
  const GtfsStaticFeed({
    required this.operatorId,
    required this.stops,
    required this.routes,
    required this.trips,
    required this.stopTimes,
    required this.calendar,
    required this.calendarDates,
    required this.frequencies,
    required this.fetchedAt,
  });

  final String operatorId;
  final List<GtfsStop> stops;
  final List<GtfsRoute> routes;
  final List<GtfsTrip> trips;
  final List<GtfsStopTime> stopTimes;
  final List<GtfsCalendarService> calendar;
  final List<GtfsCalendarDate> calendarDates;
  final List<GtfsFrequency> frequencies;
  final DateTime fetchedAt;

  bool get isEmpty => stops.isEmpty;

  bool get isUsable =>
      stops.isNotEmpty &&
      routes.isNotEmpty &&
      trips.isNotEmpty &&
      stopTimes.isNotEmpty;
}

class GtfsException implements Exception {
  GtfsException(this.message);
  final String message;

  @override
  String toString() => message;
}
