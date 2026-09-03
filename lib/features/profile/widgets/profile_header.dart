import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.accountLabel,
  });

  final String displayName;
  final String accountLabel;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'C'
        : displayName.trim().characters.first.toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.trackNavy,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                accountLabel,
                style: const TextStyle(
                  color: AppTheme.slate,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
