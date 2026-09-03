part of '../route_planner_screen.dart';

class _PlannerSelector extends StatelessWidget {
  const _PlannerSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final PlannerStopOption? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final selected = value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(
            Icons.search,
          ),
        ),
        child: selected == null
            ? Text(
                'Search station or stop',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    selected.lineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
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
                    Operators.byId(
                      selected.operatorId,
                    ).shortName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ==================================================================
// STATION PICKER
// ==================================================================
