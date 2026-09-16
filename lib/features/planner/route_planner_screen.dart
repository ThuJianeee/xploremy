import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../auth/auth_service.dart';
import '../profile/settings/saved_addresses.dart';
import '../rewards/rewards_store.dart';
import '../settings/travel_preferences.dart';
import 'planner_history.dart';
import 'planner_saved.dart';

part 'widgets/planner_selector.dart';
part 'widgets/planner_input_card.dart';
part 'widgets/recent_journeys.dart';
part 'widgets/saved_journeys.dart';
part 'widgets/saved_addresses_planner_card.dart';
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
    this.initialJourney,
    this.refreshListenable,
  });

  final PlannerHistoryEntry? initialJourney;
  final ValueListenable<int>? refreshListenable;

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
  int _planRequestId = 0;
  int _locationRequestId = 0;

  List<JourneyPlan> _journeys = const [];
  _JourneySort _sort = _JourneySort.recommended;
  List<PlannerHistoryEntry> _recent = const [];
  List<PlannerHistoryEntry> _saved = const [];
  List<SavedAddressEntry> _savedAddresses = const [];
  TravelPreferences _preferences = const TravelPreferences();

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
    TravelPreferencesStore.load().then((value) {
      if (mounted) setState(() => _preferences = value);
    });
    widget.refreshListenable?.addListener(_refreshProfilePlannerData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshProfilePlannerData();
    });
    final initialJourney = widget.initialJourney;
    if (initialJourney != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreRecent(initialJourney);
      });
    }
  }

  @override
  void didUpdateWidget(covariant RoutePlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_refreshProfilePlannerData);
      widget.refreshListenable?.addListener(_refreshProfilePlannerData);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_refreshProfilePlannerData);
    super.dispose();
  }

  Future<void> _refreshProfilePlannerData() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final userId = auth.user?.id ?? 'guest';
    final addresses = await SavedAddressStore.load(userId);
    final preferences = await TravelPreferencesStore.load();
    if (!mounted) return;
    setState(() {
      _savedAddresses = addresses;
      _preferences = preferences;
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
        if (_preferences.preferFewerTransfers ||
            _preferences.preferLessWalking ||
            _preferences.preferRail ||
            _preferences.defaultTransport != DefaultTransport.any ||
            _preferences.accessibleMode) {
          journeys.sort(
              (a, b) => _preferenceScore(a).compareTo(_preferenceScore(b)));
        }
        break;
    }
    return journeys;
  }

  double _walkingMetres(JourneyPlan journey) {
    return (journey.beforeFirstLeg?.distanceMetres ?? 0) +
        (journey.betweenLegs?.distanceMetres ?? 0) +
        (journey.afterLastLeg?.distanceMetres ?? 0);
  }

  int _preferenceScore(JourneyPlan journey) {
    var score = journey.duration.inMinutes;
    if (_preferences.preferFewerTransfers || _preferences.accessibleMode) {
      score += journey.transferCount * 25;
    }
    if (_preferences.preferLessWalking || _preferences.accessibleMode) {
      score += (_walkingMetres(journey) / 150).round();
    }
    final prefersRail = _preferences.preferRail ||
        _preferences.defaultTransport == DefaultTransport.rail;
    if (prefersRail) {
      final hasRail = journey.legs.any(
        (leg) => leg.routeType == 0 || leg.routeType == 1 || leg.routeType == 2,
      );
      if (!hasRail) score += 18;
    }
    if (_preferences.defaultTransport == DefaultTransport.bus) {
      final hasBus = journey.legs.any((leg) => leg.routeType == 3);
      if (!hasBus) score += 18;
    }
    return score;
  }

  SavedAddressEntry? get _homeAddress {
    for (final item in _savedAddresses) {
      if (item.role == SavedAddressRole.home) return item;
    }
    return null;
  }

  SavedAddressEntry? get _workAddress {
    for (final item in _savedAddresses) {
      if (item.role == SavedAddressRole.work) return item;
    }
    return null;
  }

  PlannerStopOption? get _homeStop => _homeAddress?.stop ?? _preferences.home;
  PlannerStopOption? get _workStop => _workAddress?.stop ?? _preferences.work;

  void _useHomeWork({required bool homeToWork}) {
    final home = _homeStop;
    final work = _workStop;
    if (home == null || work == null) return;
    setState(() {
      _from = homeToWork ? home : work;
      _to = homeToWork ? work : home;
      _journeys = const [];
      _searched = false;
      _sort = _JourneySort.recommended;
    });
  }

  void _useSavedAddress(
    SavedAddressEntry address, {
    required bool asOrigin,
  }) {
    setState(() {
      if (asOrigin) {
        _from = address.stop;
      } else {
        _to = address.stop;
      }
      _journeys = const [];
      _searched = false;
      _sort = _JourneySort.recommended;
    });
  }

  void _clearPlanner() {
    if (_from == null &&
        _to == null &&
        !_searched &&
        _journeys.isEmpty &&
        !_planning &&
        !_locating) {
      return;
    }
    _planRequestId++;
    _locationRequestId++;
    setState(() {
      _from = null;
      _to = null;
      _journeys = const [];
      _searched = false;
      _planning = false;
      _locating = false;
      _sort = _JourneySort.recommended;
    });
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

  Future<void> _useCurrentLocation() async {
    if (_locating) {
      return;
    }

    final requestId = ++_locationRequestId;
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

      if (!mounted || requestId != _locationRequestId) {
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

      if (!mounted || requestId != _locationRequestId) {
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
    } catch (_) {
      if (!mounted || requestId != _locationRequestId) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get your current location. Check location permission and try again.',
          ),
        ),
      );
    } finally {
      if (mounted && requestId == _locationRequestId) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  void _swap() {
    setState(() {
      final previous = _from;

      _from = _to;
      _to = previous;

      _journeys = const [];
      _searched = false;
    });
  }

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

    final requestId = ++_planRequestId;
    final repository = context.read<TransitRepository>();

    setState(() {
      _planning = true;
      _searched = true;
      _journeys = const [];
    });

    try {
      final updatedRecent = await PlannerHistoryStore.add(
        PlannerHistoryEntry.fromOptions(from: from, to: to),
      );
      await RewardsStore.incrementMission('journey_planned');
      await RewardsStore.addXp(5);

      if (!mounted || requestId != _planRequestId) return;
      setState(() => _recent = updatedRecent);

      final journeys = await repository.planJourneys(
        from: from,
        to: to,
        limit: 5,
      );

      if (!mounted || requestId != _planRequestId) return;
      setState(() {
        _journeys = journeys;
      });
    } catch (_) {
      if (!mounted || requestId != _planRequestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not plan this journey. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted && requestId == _planRequestId) {
        setState(() {
          _planning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journeys = _sortedJourneys;

    return Scaffold(
      appBar: AppBar(title: const Text('Route planner')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshProfilePlannerData();
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
            if (_savedAddresses.isNotEmpty) ...[
              _SavedAddressesPlannerCard(
                addresses: _savedAddresses,
                onUseAsFrom: (address) =>
                    _useSavedAddress(address, asOrigin: true),
                onUseAsTo: (address) =>
                    _useSavedAddress(address, asOrigin: false),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: (_from != null || _to != null || _searched)
                      ? _clearPlanner
                      : null,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear all'),
                ),
              ],
            ),
            if (_homeStop != null && _workStop != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Home → Work'),
                    onPressed: () => _useHomeWork(homeToWork: true),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.work_outline, size: 18),
                    label: const Text('Work → Home'),
                    onPressed: () => _useHomeWork(homeToWork: false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 4),
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
