part of '../route_planner_screen.dart';

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
