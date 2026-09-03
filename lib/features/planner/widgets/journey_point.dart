part of '../route_planner_screen.dart';

class _JourneyPoint extends StatelessWidget {
  const _JourneyPoint({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;

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
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(
          width: 12,
        ),
        SizedBox(
          width: 50,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// SUMMARY METRIC
// ==================================================================
