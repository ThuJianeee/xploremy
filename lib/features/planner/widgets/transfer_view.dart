part of '../route_planner_screen.dart';

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
