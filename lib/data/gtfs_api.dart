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

/// MODULE 1 — Data & API layer.
///
/// Fetches GTFS-static ZIP archives and GTFS-realtime protobuf feeds from
/// MAMPU's DTSA open data platform (api.data.gov.my). No API key required.
class GtfsApi {
  GtfsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Downloads and unzips a GTFS-static feed, returning the parsed entities.
  Future<GtfsStaticFeed> fetchStaticFeed(Operator op) async {
    final response = await _client.get(op.staticUrl);
    if (response.statusCode != 200) {
      throw GtfsException(
        'GTFS-static request for ${op.shortName} failed '
        '(HTTP ${response.statusCode})',
      );
    }
    return parseStaticArchive(op, response.bodyBytes);
  }

  /// Parses an in-memory GTFS ZIP into Dart models.
  /// Exposed separately so it can be unit-tested with a fixture file.
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
      fetchedAt: DateTime.now(),
    );
  }

  /// Live vehicle positions (GTFS-realtime protobuf).
  Future<List<VehiclePosition>> fetchVehiclePositions(Operator op) async {
    final url = op.realtimeUrl;
    if (url == null) return const [];

    final response = await _client.get(url);
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
          bearing: v.position.hasBearing() ? v.position.bearing.toDouble() : null,
          timestamp: v.hasTimestamp()
              ? DateTime.fromMillisecondsSinceEpoch(
                  v.timestamp.toInt() * 1000)
              : null,
        ),
      );
    }
    return result;
  }

  // ---------------------------------------------------------------- parsing

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
}

class GtfsStaticFeed {
  const GtfsStaticFeed({
    required this.operatorId,
    required this.stops,
    required this.routes,
    required this.trips,
    required this.stopTimes,
    required this.fetchedAt,
  });

  final String operatorId;
  final List<GtfsStop> stops;
  final List<GtfsRoute> routes;
  final List<GtfsTrip> trips;
  final List<GtfsStopTime> stopTimes;
  final DateTime fetchedAt;

  bool get isEmpty => stops.isEmpty;
}

class GtfsException implements Exception {
  GtfsException(this.message);
  final String message;
  @override
  String toString() => message;
}
