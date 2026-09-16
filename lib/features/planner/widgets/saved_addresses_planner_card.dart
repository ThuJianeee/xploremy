part of '../route_planner_screen.dart';

class _SavedAddressesPlannerCard extends StatelessWidget {
  const _SavedAddressesPlannerCard({
    required this.addresses,
    required this.onUseAsFrom,
    required this.onUseAsTo,
  });

  final List<SavedAddressEntry> addresses;
  final ValueChanged<SavedAddressEntry> onUseAsFrom;
  final ValueChanged<SavedAddressEntry> onUseAsTo;

  IconData _roleIcon(SavedAddressRole role) {
    switch (role) {
      case SavedAddressRole.home:
        return Icons.home_outlined;
      case SavedAddressRole.work:
        return Icons.work_outline;
      case SavedAddressRole.other:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_border, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saved addresses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Use a place from your Profile directly as the journey start or destination.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final address in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    child: Icon(_roleIcon(address.role), size: 18),
                  ),
                  title: Text(
                    address.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    address.stop.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Use ${address.label} as From',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onUseAsFrom(address),
                        icon: const Icon(Icons.trip_origin, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Use ${address.label} as To',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onUseAsTo(address),
                        icon: const Icon(Icons.location_on_outlined, size: 21),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
