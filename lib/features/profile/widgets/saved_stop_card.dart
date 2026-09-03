import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/station_names.dart';
import '../../../core/theme.dart';
import '../../auth/auth_service.dart';

class SavedStopCard extends StatelessWidget {
  const SavedStopCard({
    super.key,
    required this.favourite,
    required this.onOpen,
    required this.onRemove,
  });

  final FavouriteStop favourite;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.star, color: AppTheme.hibiscus),
        title: Text(cleanStationName(favourite.stopName)),
        subtitle: Text(Operators.byId(favourite.operatorId).shortName),
        onTap: onOpen,
        trailing: IconButton(
          tooltip: 'Remove favourite',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
