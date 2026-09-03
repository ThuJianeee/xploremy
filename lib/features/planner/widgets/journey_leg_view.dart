part of '../route_planner_screen.dart';

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
          if (leg.stops.length > 2) ...[
            const SizedBox(height: 10),
            Text(
              'Intermediate stops',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 5),
            for (final stop in leg.stops.skip(1).take(leg.stops.length - 2))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _cleanJourneyStopName(stop.name),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ==================================================================
// TRANSFER / WALK
// ==================================================================
