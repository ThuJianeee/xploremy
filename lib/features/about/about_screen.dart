import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

class AboutDataSourcesScreen extends StatelessWidget {
  const AboutDataSourcesScreen({super.key});

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Data Sources')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'XploreMY',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'A Malaysian public transport companion that combines official GTFS timetable data, supported GTFS-Realtime vehicle positions, offline caching and journey planning.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            title: 'Official transport data',
            icon: Icons.dataset_outlined,
            children: [
              const Text('Source: Malaysia open transport data API.'),
              const SizedBox(height: 6),
              _ExternalLink(
                label: AppConfig.dataGovBase,
                onTap: () =>
                    _openUrl(context, Uri.parse(AppConfig.dataGovBase)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Static GTFS supplies stops, routes, trips, calendars and stop times. GTFS-Realtime vehicle-position feeds are used only for operators that publish them.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Map data',
            icon: Icons.map_outlined,
            children: [
              const Text(
                'Map tiles and geographic context use OpenStreetMap. Attribution is displayed on map views.',
              ),
              const SizedBox(height: 6),
              _ExternalLink(
                label: 'https://www.openstreetmap.org',
                onTap: () => _openUrl(
                  context,
                  Uri.parse('https://www.openstreetmap.org'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: 'Realtime limitations',
            icon: Icons.sensors_outlined,
            children: [
              Text(
                'Vehicle positions are live only when the source operator provides a supported feed. Scheduled departure times remain timetable-based unless a reliable live estimate can be inferred from a matching vehicle trip.',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Configured operators',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final op in Operators.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          op.isRail
                              ? Icons.train_outlined
                              : Icons.directions_bus_outlined,
                          color: AppTheme.trackNavy,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              op.shortName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              op.hasRealtime
                                  ? 'Static + vehicle realtime'
                                  : 'Static timetable',
                              style: const TextStyle(color: AppTheme.slate),
                            ),
                            const SizedBox(height: 5),
                            _ExternalLink(
                              label: op.staticUrl.toString(),
                              onTap: () => _openUrl(context, op.staticUrl),
                            ),
                            if (op.realtimeUrl != null) ...[
                              const SizedBox(height: 5),
                              _ExternalLink(
                                label: 'Realtime: ${op.realtimeUrl}',
                                onTap: () => _openUrl(context, op.realtimeUrl!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Version 1.1 Enhanced · Data availability and service schedules remain controlled by the respective official publishers.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.slate),
          ),
        ],
      ),
    );
  }
}

class _ExternalLink extends StatelessWidget {
  const _ExternalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.signalTeal),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
