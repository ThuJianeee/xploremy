import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import 'planner_history.dart';
import 'planner_saved.dart';

part 'widgets/planner_selector.dart';
part 'widgets/planner_input_card.dart';
part 'widgets/recent_journeys.dart';
part 'widgets/saved_journeys.dart';
part 'widgets/planner_history_actions.dart';
part 'widgets/planner_stop_picker.dart';
part 'widgets/planner_info.dart';
part 'widgets/journey_card.dart';
part 'widgets/journey_leg_view.dart';
part 'widgets/transfer_view.dart';
part 'widgets/journey_point.dart';
part 'widgets/journey_metric.dart';

enum _JourneySort { recommended, fastest, fewestTransfers, leastWalking }

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({
    super.key,
  });

  @override
  State<RoutePlannerScreen> createState() {
    return _RoutePlannerScreenState();
  }
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  PlannerStopOption? _from;
  PlannerStopOption? _to;

  bool _locating = false;
  bool _planning = false;
  bool _searched = false;

  List<JourneyPlan> _journeys = const [];
  _JourneySort _sort = _JourneySort.recommended;
  List<PlannerHistoryEntry> _recent = const [];
  List<PlannerHistoryEntry> _saved = const [];

  void _applyRestoredJourney(
    PlannerStopOption from,
    PlannerStopOption to,
  ) {
    setState(() {
      _from = from;
      _to = to;
      _journeys = const [];
      _searched = false;
    });
  }

  void _replaceRecentJourneys(List<PlannerHistoryEntry> entries) {
    setState(() {
      _recent = entries;
    });
  }

  void _replaceSavedJourneys(List<PlannerHistoryEntry> entries) {
    setState(() {
      _saved = entries;
    });
  }

  @override
  void initState() {
    super.initState();
    PlannerHistoryStore.load().then((entries) {
      if (mounted) setState(() => _recent = entries);
    });
    PlannerSavedStore.load().then((entries) {
      if (mounted) setState(() => _saved = entries);
    });
  }

  List<JourneyPlan> get _sortedJourneys {
    final journeys = [..._journeys];
    switch (_sort) {
      case _JourneySort.fastest:
        journeys.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case _JourneySort.fewestTransfers:
        journeys.sort((a, b) {
          final byTransfer = a.transferCount.compareTo(b.transferCount);
          return byTransfer != 0
              ? byTransfer
              : a.duration.compareTo(b.duration);
        });
        break;
      case _JourneySort.leastWalking:
        journeys.sort((a, b) => _walkingMetres(a).compareTo(_walkingMetres(b)));
        break;
      case _JourneySort.recommended:
        break;
    }
    return journeys;
  }

  double _walkingMetres(JourneyPlan journey) {
    return (journey.beforeFirstLeg?.distanceMetres ?? 0) +
        (journey.betweenLegs?.distanceMetres ?? 0) +
        (journey.afterLastLeg?.distanceMetres ?? 0);
  }

  PlannerHistoryEntry? get _currentEntry {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    return PlannerHistoryEntry.fromOptions(from: from, to: to);
  }

  bool get _currentIsSaved {
    final entry = _currentEntry;
    if (entry == null) return false;
    return _saved.any((item) => item.key == entry.key);
  }

  Future<void> _toggleCurrentSaved() async {
    final entry = _currentEntry;
    if (entry == null) return;

    final updated = _currentIsSaved
        ? await PlannerSavedStore.remove(entry.key)
        : await PlannerSavedStore.add(entry);

    if (!mounted) return;
    setState(() => _saved = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentIsSaved
              ? 'Journey saved on this device.'
              : 'Journey removed from saved journeys.',
        ),
      ),
    );
  }

  // ==============================================================
  // STATION SELECTION
  // ==============================================================

  Future<void> _selectFrom() async {
    final result = await _openPicker(
      title: 'Select starting station',
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _from = result;
      _journeys = const [];
      _searched = false;
    });
  }

  Future<void> _selectTo() async {
    final result = await _openPicker(
      title: 'Select destination',
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _to = result;
      _journeys = const [];
      _searched = false;
    });
  }

  Future<PlannerStopOption?> _openPicker({
    required String title,
  }) {
    final repository = context.read<TransitRepository>();

    return showModalBottomSheet<PlannerStopOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _PlannerStopPicker(
          title: title,
          repository: repository,
        );
      },
    );
  }

  // ==============================================================
  // CURRENT LOCATION
  // ==============================================================

  Future<void> _useCurrentLocation() async {
    if (_locating) {
      return;
    }

    final repository = context.read<TransitRepository>();

    setState(() {
      _locating = true;
    });

    try {
      final location = await LocationService.current();

      final nearby = await repository.getNearbyStops(
        lat: location.lat,
        lon: location.lon,
        radiusMetres: 3000,
        limit: 20,
      );

      if (!mounted) {
        return;
      }

      if (nearby.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No downloaded stops were found near your location.',
            ),
          ),
        );

        return;
      }

      PlannerStopOption? option;

      /// Try each nearby physical stop until one has route information.
      for (final stop in nearby) {
        final options = await repository.plannerOptionsForStop(
          operatorId: stop.operatorId,
          stopId: stop.stopId,
        );

        if (options.isNotEmpty) {
          option = options.first;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      if (option == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A nearby stop was found but no route information is available.',
            ),
          ),
        );

        return;
      }

      setState(() {
        _from = option;
        _journeys = const [];
        _searched = false;
      });

      final message = location.message;

      final text = message == null
          ? 'Nearest station selected: '
              '${option.displayName} · ${option.lineName}'
          : '$message '
              'Selected ${option.displayName} · ${option.lineName}.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not get current location: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  // ==============================================================
  // SWAP
  // ==============================================================

  void _swap() {
    setState(() {
      final previous = _from;

      _from = _to;
      _to = previous;

      _journeys = const [];
      _searched = false;
    });
  }

  // ==============================================================
  // PLAN JOURNEY
  // ==============================================================

  Future<void> _plan() async {
    final from = _from;
    final to = _to;

    if (from == null || to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both a starting station and destination.',
          ),
        ),
      );

      return;
    }

    if (from.operatorId == to.operatorId &&
        from.routeId == to.routeId &&
        from.displayName.toUpperCase() == to.displayName.toUpperCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Starting station and destination must be different.',
          ),
        ),
      );

      return;
    }

    final repository = context.read<TransitRepository>();

    // A recent journey represents a route-planning attempt, not only a
    // successful result. Saving it before the query makes the history
    // reliable even when the timetable has no suitable journey.
    final updatedRecent = await PlannerHistoryStore.add(
      PlannerHistoryEntry.fromOptions(from: from, to: to),
    );

    if (!mounted) return;
    setState(() {
      _recent = updatedRecent;
      _planning = true;
      _searched = true;
      _journeys = const [];
    });

    try {
      /// IMPORTANT:
      ///
      /// planJourneys first tries direct route.
      /// If none exists, it tries one-transfer / multi-modal route.
      final journeys = await repository.planJourneys(
        from: from,
        to: to,
        limit: 5,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _journeys = journeys;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not plan journey: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _planning = false;
        });
      }
    }
  }

  // ==============================================================
  // UI
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final journeys = _sortedJourneys;

    return Scaffold(
      appBar: AppBar(title: const Text('Route planner')),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_from != null && _to != null) await _plan();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Plan your journey',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your stations and XploreMY will find a direct or one-transfer journey using downloaded GTFS data.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 18),
            _PlannerInputCard(
              from: _from,
              to: _to,
              locating: _locating,
              planning: _planning,
              onSelectFrom: _selectFrom,
              onSelectTo: _selectTo,
              onSwap: _swap,
              onUseCurrentLocation: _useCurrentLocation,
              onPlan: _plan,
            ),
            const SizedBox(height: 20),
            if (!_searched && _saved.isNotEmpty) ...[
              _SavedJourneys(
                entries: _saved,
                onTap: (entry) => _restoreRecent(entry),
                onRemove: _removeSaved,
              ),
              const SizedBox(height: 16),
            ],
            if (!_searched && _recent.isNotEmpty) ...[
              _RecentJourneys(
                entries: _recent,
                onTap: (entry) => _restoreRecent(entry),
                onClear: _clearRecent,
              ),
              const SizedBox(height: 20),
            ],
            if (!_searched) ...[
              if (_saved.isEmpty && _recent.isEmpty) const _PlannerInfo(),
            ] else if (_planning)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_journeys.isEmpty)
              _NoJourney(from: _from, to: _to)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recommended journeys',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: _currentIsSaved
                        ? 'Remove saved journey'
                        : 'Save journey',
                    onPressed: _toggleCurrentSaved,
                    icon: Icon(
                      _currentIsSaved ? Icons.bookmark : Icons.bookmark_outline,
                    ),
                  ),
                  PopupMenuButton<_JourneySort>(
                    tooltip: 'Sort journeys',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _JourneySort.recommended,
                        child: Text('Recommended'),
                      ),
                      PopupMenuItem(
                        value: _JourneySort.fastest,
                        child: Text('Fastest'),
                      ),
                      PopupMenuItem(
                        value: _JourneySort.fewestTransfers,
                        child: Text('Fewest transfers'),
                      ),
                      PopupMenuItem(
                        value: _JourneySort.leastWalking,
                        child: Text('Least walking'),
                      ),
                    ],
                    icon: const Icon(Icons.sort),
                  ),
                ],
              ),
              Text(
                '${journeys.length} found',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              for (final journey in journeys) _JourneyCard(journey: journey),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// SELECTED STATION FIELD
// ==================================================================
