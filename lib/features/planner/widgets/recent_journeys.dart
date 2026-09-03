part of '../route_planner_screen.dart';

class _RecentJourneys extends StatelessWidget {
  const _RecentJourneys({
    required this.entries,
    required this.onTap,
    required this.onClear,
  });

  final List<PlannerHistoryEntry> entries;
  final ValueChanged<PlannerHistoryEntry> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent journeys',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.history),
                title: Text('${entry.fromName} → ${entry.toName}'),
                subtitle: Text(
                  '${Operators.byId(entry.fromOperatorId).shortName} · '
                  '${Operators.byId(entry.toOperatorId).shortName}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onTap(entry),
              ),
          ],
        ),
      ),
    );
  }
}
