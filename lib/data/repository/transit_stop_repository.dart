part of '../transit_repository.dart';

extension TransitStopRepository on TransitRepository {
  Future<List<GtfsStop>> getNearbyStops({
    required double lat,
    required double lon,
    double radiusMetres = AppConfig.nearbyRadiusMetres,
    List<String>? operatorIds,
    int limit = 40,
  }) {
    return _store.nearbyStops(
      lat: lat,
      lon: lon,
      radiusMetres: radiusMetres,
      operatorIds: operatorIds,
      limit: limit,
    );
  }

  Future<List<GtfsStop>> searchStops(
    String query,
  ) {
    return _store.searchStops(query);
  }

  Future<List<PlannerStopOption>> searchPlannerStops(
    String query,
  ) {
    return _store.searchPlannerStops(
      query,
    );
  }

  Future<List<PlannerStopOption>> plannerOptionsForStop({
    required String operatorId,
    required String stopId,
  }) {
    return _store.plannerOptionsForStop(
      operatorId: operatorId,
      stopId: stopId,
    );
  }

  Future<GtfsStop?> getStop(
    String operatorId,
    String stopId,
  ) {
    return _store.stopById(
      operatorId,
      stopId,
    );
  }

}
