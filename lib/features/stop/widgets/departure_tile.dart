part of '../stop_detail_screen.dart';

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (departure.reliability) {
      Reliability.onTime => (AppTheme.onTime, 'Estimated on time'),
      Reliability.delayed => (
          AppTheme.delayed,
          'Est. late by ${formatCountdown(departure.liveDelaySeconds!.abs())}'
        ),
      Reliability.early => (
          AppTheme.signalTeal,
          'Est. early by ${formatCountdown(departure.liveDelaySeconds!.abs())}'
        ),
      Reliability.scheduled => (AppTheme.slate, 'Scheduled'),
    };

    final routeDetails = departure.routeLongName.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: const BoxConstraints(minWidth: 56, maxWidth: 96),
              decoration: BoxDecoration(
                color: AppTheme.trackNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                departure.routeLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departure.headsign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (routeDetails.isNotEmpty &&
                      routeDetails.toLowerCase() !=
                          departure.headsign.toLowerCase()) ...[
                    const SizedBox(height: 2),
                    Text(
                      routeDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.slate,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        height: 7,
                        width: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$statusLabel · ${formatDepartureTime(departure.scheduledAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCountdown(departure.secondsUntil),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.trackNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
