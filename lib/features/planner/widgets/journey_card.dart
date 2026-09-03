part of '../route_planner_screen.dart';

class _JourneyCard extends StatefulWidget {
  const _JourneyCard({required this.journey});

  final JourneyPlan journey;

  @override
  State<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<_JourneyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.isDirect
                            ? 'Direct journey'
                            : 'Transfer journey',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatJourneyTime(journey.journeyStartAt)} → '
                        '${_formatJourneyTime(journey.journeyEndAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_expanded ? 'Hide details' : 'View details'),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 20),
              if (journey.beforeFirstLeg != null) ...[
                _TransferView(transfer: journey.beforeFirstLeg!),
                const SizedBox(height: 14),
              ],
              for (var i = 0; i < journey.legs.length; i++) ...[
                _JourneyLegView(leg: journey.legs[i]),
                if (i == 0 && journey.betweenLegs != null) ...[
                  const SizedBox(height: 12),
                  _TransferView(transfer: journey.betweenLegs!),
                  const SizedBox(height: 12),
                ] else if (i < journey.legs.length - 1)
                  const SizedBox(height: 12),
              ],
              if (journey.afterLastLeg != null) ...[
                const SizedBox(height: 14),
                _TransferView(transfer: journey.afterLastLeg!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
