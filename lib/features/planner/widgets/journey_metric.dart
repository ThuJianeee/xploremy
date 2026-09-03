part of '../route_planner_screen.dart';

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// DISPLAY HELPERS
// ==================================================================

String _formatJourneyTime(
  DateTime value,
) {
  final hour = value.hour.toString().padLeft(
        2,
        '0',
      );

  final minute = value.minute.toString().padLeft(
        2,
        '0',
      );

  return '$hour:$minute';
}

String _cleanJourneyStopName(
  String value,
) {
  return value
      .replaceAll(
        RegExp(
          r'\s*-\s*REDONE\s*$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}
