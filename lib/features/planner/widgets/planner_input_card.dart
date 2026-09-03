part of '../route_planner_screen.dart';

class _PlannerInputCard extends StatelessWidget {
  const _PlannerInputCard({
    required this.from,
    required this.to,
    required this.locating,
    required this.planning,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onSwap,
    required this.onUseCurrentLocation,
    required this.onPlan,
  });

  final PlannerStopOption? from;
  final PlannerStopOption? to;
  final bool locating;
  final bool planning;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onSwap;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _PlannerSelector(
              label: 'From',
              value: from,
              icon: Icons.trip_origin,
              onTap: onSelectFrom,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                tooltip: 'Swap stations',
                onPressed: onSwap,
                icon: const Icon(Icons.swap_vert),
              ),
            ),
            const SizedBox(height: 8),
            _PlannerSelector(
              label: 'To',
              value: to,
              icon: Icons.location_on_outlined,
              onTap: onSelectTo,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: locating ? null : onUseCurrentLocation,
                icon: locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  locating ? 'Finding nearest station...' : 'Use current location',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: planning ? null : onPlan,
                icon: planning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route),
                label: Text(planning ? 'Planning...' : 'Plan journey'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
