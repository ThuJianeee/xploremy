import '../core/config.dart';
import '../core/geo.dart';
import 'gtfs_api.dart';
import 'local_store.dart';
import 'models.dart';

part 'repository/transit_sync_repository.dart';
part 'repository/transit_stop_repository.dart';
part 'repository/transit_departure_repository.dart';
part 'repository/transit_direct_planner.dart';
part 'repository/transit_transfer_planner.dart';
part 'repository/transit_repository_models.dart';

class TransitRepository {
  TransitRepository({
    GtfsApi? api,
    LocalGtfsStore? store,
  })  : _api = api ?? GtfsApi(),
        _store = store ?? LocalGtfsStore();

  final GtfsApi _api;
  final LocalGtfsStore _store;

  final Map<String, List<VehiclePosition>> _vehicleCache = {};

  final Map<String, DateTime> _vehicleFetchedAt = {};

  LocalGtfsStore get store => _store;
}
