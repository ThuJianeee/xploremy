import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

class AboutDataSourcesScreen extends StatelessWidget {
  const AboutDataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Data Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('XploreMY', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('A Malaysian public transport companion that combines official GTFS timetable data, supported GTFS-Realtime vehicle positions, offline caching and journey planning.', style: TextStyle(height: 1.45)),
          const SizedBox(height: 18),
          const _InfoCard(
            title: 'Official transport data',
            icon: Icons.dataset_outlined,
            children: [
              Text('Source: Malaysia open transport data API (api.data.gov.my).'),
              SizedBox(height: 6),
              Text('Static GTFS supplies stops, routes, trips, calendars and stop times. GTFS-Realtime vehicle-position feeds are used only for operators that publish them.'),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Map data',
            icon: Icons.map_outlined,
            children: [
              Text('Map tiles and geographic context use OpenStreetMap. Attribution is displayed on map views.'),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Realtime limitations',
            icon: Icons.sensors_outlined,
            children: [
              Text('Vehicle positions are live only when the source operator provides a supported feed. Scheduled departure times remain timetable-based unless a reliable live estimate can be inferred from a matching vehicle trip.'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Configured operators', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final op in Operators.all)
            Card(child: ListTile(
              leading: Icon(op.isRail ? Icons.train_outlined : Icons.directions_bus_outlined, color: AppTheme.trackNavy),
              title: Text(op.shortName),
              subtitle: Text('${op.hasRealtime ? 'Static + vehicle realtime' : 'Static timetable'}\n${AppConfig.dataGovBase}${op.staticPath}'),
              isThreeLine: true,
            )),
          const SizedBox(height: 12),
          const Text('Version 1.1 Enhanced · Data availability and service schedules remain controlled by the respective official publishers.', style: TextStyle(fontSize: 11.5, color: AppTheme.slate)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: AppTheme.signalTeal), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          ...children,
        ]),
      ));
}
