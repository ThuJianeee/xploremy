part of '../route_planner_screen.dart';

extension _PlannerHistoryActions on _RoutePlannerScreenState {
  Future<void> _restoreRecent(PlannerHistoryEntry entry) async {
    final repository = context.read<TransitRepository>();

    Future<PlannerStopOption?> resolve(
      String name,
      String operatorId,
      String routeId,
    ) async {
      final options = await repository.searchPlannerStops(name);
      for (final option in options) {
        if (option.operatorId == operatorId && option.routeId == routeId) {
          return option;
        }
      }
      return null;
    }

    final from = await resolve(
      entry.fromName,
      entry.fromOperatorId,
      entry.fromRouteId,
    );
    final to = await resolve(
      entry.toName,
      entry.toOperatorId,
      entry.toRouteId,
    );

    if (!mounted) return;
    if (from == null || to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This recent journey is not available in the current offline data.',
          ),
        ),
      );
      return;
    }

    _applyRestoredJourney(from, to);
    await _plan();
  }

  Future<void> _clearRecent() async {
    await PlannerHistoryStore.clear();
    if (mounted) _replaceRecentJourneys(const []);
  }

  Future<void> _removeSaved(PlannerHistoryEntry entry) async {
    final updated = await PlannerSavedStore.remove(entry.key);
    if (mounted) {
      _replaceSavedJourneys(updated);
    }
  }

}
