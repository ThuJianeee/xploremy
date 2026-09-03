part of '../route_planner_screen.dart';

class _SavedJourneys extends StatelessWidget {
  const _SavedJourneys({
    required this.entries,
    required this.onTap,
    required this.onRemove,
  });

  final List<PlannerHistoryEntry> entries;
  final ValueChanged<PlannerHistoryEntry> onTap;
  final ValueChanged<PlannerHistoryEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bookmark_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Saved journeys',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.route_outlined),
                title: Text('${entry.fromName} → ${entry.toName}'),
                subtitle: Text(
                  '${Operators.byId(entry.fromOperatorId).shortName} · '
                  '${Operators.byId(entry.toOperatorId).shortName}',
                ),
                trailing: IconButton(
                  tooltip: 'Remove saved journey',
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: () => onRemove(entry),
                ),
                onTap: () => onTap(entry),
              ),
          ],
        ),
      ),
    );
  }
}
