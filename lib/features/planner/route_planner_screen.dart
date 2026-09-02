import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';

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

    setState(() {
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route planner',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_from != null && _to != null) {
            await _plan();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            Text(
              'Plan your journey',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              'Choose your stations and XploreMY will find a direct or one-transfer public transport journey using downloaded GTFS data.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(
              height: 18,
            ),

            // ------------------------------------------------------
            // PLANNER INPUT CARD
            // ------------------------------------------------------

            Card(
              child: Padding(
                padding: const EdgeInsets.all(
                  14,
                ),
                child: Column(
                  children: [
                    _PlannerSelector(
                      label: 'From',
                      value: _from,
                      icon: Icons.trip_origin,
                      onTap: _selectFrom,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        tooltip: 'Swap stations',
                        onPressed: _swap,
                        icon: const Icon(
                          Icons.swap_vert,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _PlannerSelector(
                      label: 'To',
                      value: _to,
                      icon: Icons.location_on_outlined,
                      onTap: _selectTo,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                              ),
                        label: Text(
                          _locating
                              ? 'Finding nearest station...'
                              : 'Use current location',
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _planning ? null : _plan,
                        icon: _planning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.route,
                              ),
                        label: Text(
                          _planning ? 'Planning...' : 'Plan journey',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ------------------------------------------------------
            // RESULTS
            // ------------------------------------------------------

            if (!_searched)
              const _PlannerInfo()
            else if (_planning)
              const Padding(
                padding: EdgeInsets.only(
                  top: 30,
                ),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_journeys.isEmpty)
              _NoJourney(
                from: _from,
                to: _to,
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recommended journeys',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    '${_journeys.length} found',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 12,
              ),
              for (final journey in _journeys)
                _JourneyCard(
                  journey: journey,
                ),
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

class _PlannerSelector extends StatelessWidget {
  const _PlannerSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final PlannerStopOption? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final selected = value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(
            Icons.search,
          ),
        ),
        child: selected == null
            ? Text(
                'Search station or stop',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    selected.lineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    Operators.byId(
                      selected.operatorId,
                    ).shortName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ==================================================================
// STATION PICKER
// ==================================================================

class _PlannerStopPicker extends StatefulWidget {
  const _PlannerStopPicker({
    required this.title,
    required this.repository,
  });

  final String title;
  final TransitRepository repository;

  @override
  State<_PlannerStopPicker> createState() {
    return _PlannerStopPickerState();
  }
}

class _PlannerStopPickerState extends State<_PlannerStopPicker> {
  final _searchController = TextEditingController();

  List<PlannerStopOption> _results = const [];

  bool _busy = false;
  bool _searched = false;

  int _requestId = 0;

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _search(
    String value,
  ) async {
    final query = value.trim();

    final requestId = ++_requestId;

    if (query.length < 2) {
      setState(() {
        _results = const [];
        _busy = false;
        _searched = false;
      });

      return;
    }

    setState(() {
      _busy = true;
      _searched = true;
    });

    try {
      final result = await widget.repository.searchPlannerStops(
        query,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _results = result;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _results = const [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not search stops: $e',
          ),
        ),
      );
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(
          context,
        ).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(
              context,
            ).height *
            0.80,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                8,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search KL Sentral, KLCC...',
                  prefixIcon: Icon(
                    Icons.search,
                  ),
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _resultsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsContent() {
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(
            24,
          ),
          child: Text(
            'Enter at least 2 characters to search downloaded stations.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_busy && _results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(
            24,
          ),
          child: Text(
            'No matching station or route was found in the downloaded GTFS data.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        8,
        4,
        8,
        24,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, __) {
        return const Divider(
          height: 1,
        );
      },
      itemBuilder: (context, index) {
        final option = _results[index];

        final operator = Operators.byId(
          option.operatorId,
        );

        return ListTile(
          leading: CircleAvatar(
            child: Icon(
              _routeIcon(
                option.routeType,
              ),
            ),
          ),
          title: Text(
            option.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 2,
              ),
              Text(
                option.lineName,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                option.stops.length > 1
                    ? '${operator.shortName} · '
                        '${option.stops.length} stop records'
                    : operator.shortName,
              ),
            ],
          ),
          trailing: const Icon(
            Icons.chevron_right,
          ),
          onTap: () {
            Navigator.pop(
              context,
              option,
            );
          },
        );
      },
    );
  }

  IconData _routeIcon(
    int type,
  ) {
    switch (type) {
      case 0:
        return Icons.tram;

      case 1:
        return Icons.subway;

      case 2:
        return Icons.train;

      case 3:
        return Icons.directions_bus;

      default:
        return Icons.directions_transit;
    }
  }
}

// ==================================================================
// PLANNER INFORMATION
// ==================================================================

class _PlannerInfo extends StatelessWidget {
  const _PlannerInfo();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary,
                ),
                const SizedBox(
                  width: 10,
                ),
                const Expanded(
                  child: Text(
                    'Journey planning',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'XploreMY can search direct services and one-transfer journeys using the GTFS timetable stored on your device.',
            ),
            const SizedBox(
              height: 12,
            ),
            const _InfoRow(
              icon: Icons.train_outlined,
              text: 'Shows the exact rail or bus line serving each station',
            ),
            const SizedBox(
              height: 8,
            ),
            const _InfoRow(
              icon: Icons.swap_horiz_outlined,
              text: 'Supports direct and one-transfer journeys',
            ),
            const SizedBox(
              height: 8,
            ),
            const _InfoRow(
              icon: Icons.directions_walk,
              text:
                  'Estimates walking time between nearby interchange stations',
            ),
            const SizedBox(
              height: 8,
            ),
            const _InfoRow(
              icon: Icons.cloud_off_outlined,
              text: 'Journey search works from downloaded GTFS data',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade700,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}

// ==================================================================
// NO RESULT
// ==================================================================

class _NoJourney extends StatelessWidget {
  const _NoJourney({
    required this.from,
    required this.to,
  });

  final PlannerStopOption? from;
  final PlannerStopOption? to;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          20,
        ),
        child: Column(
          children: [
            Icon(
              Icons.alt_route,
              size: 44,
              color: Colors.grey.shade600,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'No suitable journey found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'No valid direct or one-transfer journey was found using the currently downloaded timetable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              'Try another line, refresh the offline GTFS data, or select another interchange.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// JOURNEY RESULT CARD
// ==================================================================

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.journey,
  });

  final JourneyPlan journey;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    journey.isDirect
                        ? 'Direct journey'
                        : 'Recommended transfer journey',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    journey.isDirect
                        ? 'Direct'
                        : '${journey.transferCount} transfer',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // ------------------------------------------------------
            // WALK / CHANGE BEFORE FIRST TRANSIT LEG
            // ------------------------------------------------------

            if (journey.beforeFirstLeg != null) ...[
              _TransferView(
                transfer: journey.beforeFirstLeg!,
              ),
              const SizedBox(
                height: 14,
              ),
            ],

            // ------------------------------------------------------
            // TRANSIT LEGS
            // ------------------------------------------------------

            for (var i = 0; i < journey.legs.length; i++) ...[
              _JourneyLegView(
                leg: journey.legs[i],
              ),
              if (i == 0 && journey.betweenLegs != null) ...[
                const SizedBox(
                  height: 12,
                ),
                _TransferView(
                  transfer: journey.betweenLegs!,
                ),
                const SizedBox(
                  height: 12,
                ),
              ] else if (i < journey.legs.length - 1)
                const SizedBox(
                  height: 12,
                ),
            ],

            // ------------------------------------------------------
            // WALK / CHANGE AFTER LAST LEG
            // ------------------------------------------------------

            if (journey.afterLastLeg != null) ...[
              const SizedBox(
                height: 14,
              ),
              _TransferView(
                transfer: journey.afterLastLeg!,
              ),
            ],

            const Divider(
              height: 28,
            ),

            // ------------------------------------------------------
            // JOURNEY SUMMARY
            // ------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _JourneyMetric(
                    icon: Icons.schedule_outlined,
                    label: 'Total time',
                    value: '${journey.duration.inMinutes} min',
                  ),
                ),
                Expanded(
                  child: _JourneyMetric(
                    icon: Icons.train_outlined,
                    label: 'Stops',
                    value: '${journey.stopCount}',
                  ),
                ),
                Expanded(
                  child: _JourneyMetric(
                    icon: Icons.swap_horiz,
                    label: 'Transfers',
                    value: '${journey.transferCount}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// TRANSIT LEG
// ==================================================================

class _JourneyLegView extends StatelessWidget {
  const _JourneyLegView({
    required this.leg,
  });

  final JourneyLeg leg;

  @override
  Widget build(
    BuildContext context,
  ) {
    final routeName = leg.routeLongName.trim().isNotEmpty
        ? leg.routeLongName
        : leg.routeLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary,
                  borderRadius: BorderRadius.circular(
                    7,
                  ),
                ),
                child: Text(
                  leg.routeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (leg.headsign.trim().isNotEmpty)
                      Text(
                        'Towards ${leg.headsign}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          _JourneyPoint(
            time: _formatJourneyTime(
              leg.departureAt,
            ),
            title: _cleanJourneyStopName(
              leg.fromStop.name,
            ),
            subtitle: 'Board',
            icon: Icons.trip_origin,
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 9,
            ),
            child: Container(
              width: 2,
              height: 28,
              color: Colors.grey.shade300,
            ),
          ),
          _JourneyPoint(
            time: _formatJourneyTime(
              leg.arrivalAt,
            ),
            title: _cleanJourneyStopName(
              leg.toStop.name,
            ),
            subtitle: 'Exit / transfer',
            icon: Icons.location_on,
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            '${leg.stopCount} stops · '
            '${leg.duration.inMinutes} min',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// TRANSFER / WALK
// ==================================================================

class _TransferView extends StatelessWidget {
  const _TransferView({
    required this.transfer,
  });

  final JourneyTransfer transfer;

  @override
  Widget build(
    BuildContext context,
  ) {
    final fromName = _cleanJourneyStopName(
      transfer.fromStop.name,
    );

    final toName = _cleanJourneyStopName(
      transfer.toStop.name,
    );

    final sameName = fromName.toUpperCase() == toName.toUpperCase();

    final metres = transfer.distanceMetres.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.directions_walk,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sameName ? 'Change line at $fromName' : 'Walk to transfer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  sameName
                      ? 'Allow about ${transfer.walkMinutes} min to change platform or line.'
                      : '$fromName → $toName\n'
                          'About ${transfer.walkMinutes} min · approximately $metres m',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// TIMELINE POINT
// ==================================================================

class _JourneyPoint extends StatelessWidget {
  const _JourneyPoint({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(
          width: 12,
        ),
        SizedBox(
          width: 50,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// SUMMARY METRIC
// ==================================================================

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// DISPLAY HELPERS
// ==================================================================

String _formatJourneyTime(
  DateTime value,
) {
  final hour = value.hour.toString().padLeft(
        2,
        '0',
      );

  final minute = value.minute.toString().padLeft(
        2,
        '0',
      );

  return '$hour:$minute';
}

String _cleanJourneyStopName(
  String value,
) {
  return value
      .replaceAll(
        RegExp(
          r'\s*-\s*REDONE\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}
