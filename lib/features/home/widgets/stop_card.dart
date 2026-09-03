import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/geo.dart';
import '../../../core/station_names.dart';
import '../../../core/theme.dart';
import '../../../data/models.dart';

class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.stop,
    required this.onTap,
  });

  final GtfsStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final op = Operators.byId(stop.operatorId);
    final isRail = op.isRail || op.id.contains('rail');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppTheme.trackNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRail ? Icons.train_outlined : Icons.directions_bus_outlined,
                  color: AppTheme.trackNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanStationName(stop.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      op.shortName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (stop.distanceMetres != null)
                Text(
                  formatDistance(stop.distanceMetres!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.signalTeal,
                  ),
                ),
              const Icon(Icons.chevron_right, color: AppTheme.slate),
            ],
          ),
        ),
      ),
    );
  }
}
