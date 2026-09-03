part of '../transit_repository.dart';

extension TransitSyncRepository on TransitRepository {
  Future<DateTime?> lastSync(
    String operatorId,
  ) {
    return _store.lastSync(
      operatorId,
    );
  }

  Future<List<String>> syncedOperatorIds() {
    return _store.cachedOperatorIds();
  }

  Future<SyncResult> syncOperator(
    Operator op, {
    bool force = false,
  }) async {
    final last = await _store.lastSync(
      op.id,
    );

    if (!force &&
        last != null &&
        DateTime.now().difference(last) < AppConfig.staticFeedTtl) {
      return SyncResult(
        operator: op,
        skipped: true,
        stops: 0,
      );
    }

    final feed = await _api.fetchStaticFeed(
      op,
    );

    if (!feed.isUsable) {
      throw GtfsException(
        '${op.shortName} returned an incomplete GTFS feed.',
      );
    }

    await _store.saveFeed(feed);

    return SyncResult(
      operator: op,
      skipped: false,
      stops: feed.stops.length,
    );
  }

  Future<List<SyncResult>> syncAll(
    List<Operator> operators, {
    bool force = false,
    void Function(Operator op)? onProgress,
  }) async {
    final results = <SyncResult>[];

    for (final op in operators) {
      onProgress?.call(op);

      try {
        results.add(
          await syncOperator(
            op,
            force: force,
          ),
        );
      } catch (e) {
        results.add(
          SyncResult(
            operator: op,
            skipped: false,
            stops: 0,
            error: '$e',
          ),
        );
      }
    }

    return results;
  }

  Future<void> loadMockFeed() async {
    for (final feed in buildMockFeeds()) {
      await _store.saveFeed(feed);
    }
  }

  Future<void> clearCache() {
    return _store.clear();
  }

  // ==============================================================
  // STOPS
  // ==============================================================

}
