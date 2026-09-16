import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.accountLabel,
    this.avatarUrl,
    this.onAvatarTap,
    this.avatarBusy = false,
  });

  final String displayName;
  final String accountLabel;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
  final bool avatarBusy;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'C'
        : displayName.trim().characters.first.toUpperCase();
    final hasAvatar = avatarUrl?.trim().isNotEmpty == true;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.trackNavy,
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: avatarBusy ? null : onAvatarTap,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: avatarBusy
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            size: 17,
                            color: AppTheme.signalTeal,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 4),
              Text(
                hasAvatar
                    ? 'Tap photo to change avatar'
                    : 'Tap camera to add avatar',
                style: const TextStyle(
                  color: AppTheme.signalTeal,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
