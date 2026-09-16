import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../planner/planner_history.dart';
import '../../planner/planner_saved.dart';
import '../../rewards/rewards_store.dart';
import '../../settings/travel_preferences.dart';
import '../favorites/favorites_folder_store.dart';
import 'notification_preferences.dart';
import 'saved_addresses.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final auth = context.read<AuthService>();
    final userId = auth.user?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    setState(() => _deleting = true);
    var cloudDeleted = false;
    try {
      await auth.deleteAccount(deferUiNotification: true);
      cloudDeleted = true;

      await Future.wait([
        SavedAddressStore.clear(userId),
        NotificationPreferencesStore.clear(userId),
        FavoritesFolderStore.clear(userId),
        TravelPreferencesStore.clear(),
        PlannerHistoryStore.clear(),
        PlannerSavedStore.clear(),
        RewardsStore.clear(),
      ].map((future) async {
        try {
          await future;
        } catch (_) {}
      }));

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        await WidgetsBinding.instance.endOfFrame;
      }
      auth.finishDeferredAccountDeletion();
    } catch (error) {
      if (cloudDeleted) {
        auth.finishDeferredAccountDeletion();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account could not be deleted. Make sure the latest XploreMY Supabase SQL has been applied. ($error)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Signed-in email'),
              subtitle: Text(auth.user?.email ?? 'Not available'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Danger zone',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text(
                'Delete account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Permanently delete your account and user-owned cloud data.',
              ),
              trailing: _deleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _deleting ? null : _deleteAccount,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Account deletion uses the secure delete_my_account Supabase function included in the enhanced SQL. No service-role key is stored in the app.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _confirmed => _controller.text.trim() == 'DELETE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permanently delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently removes your XploreMY account and user-owned cloud data. This action cannot be undone.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Type DELETE to confirm:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            'Delete permanently',
            style: TextStyle(
              color: _confirmed ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
      ],
    );
  }
}
