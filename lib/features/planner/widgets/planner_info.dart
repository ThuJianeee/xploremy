part of '../route_planner_screen.dart';

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
