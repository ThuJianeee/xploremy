import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';

/// MODULE 4 (d) — manage profile information.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  String? _operatorId;
  bool _busy = false;
  bool _initialised = false;
  List<FavouriteStop> _favourites = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final auth = context.read<AuthService>();
    await auth.refreshProfile();
    final profile = auth.profile;
    List<FavouriteStop> favourites = const [];
    try {
      favourites = await auth.favouriteStops();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _name.text = profile?.fullName ?? '';
      _phone.text = profile?.phone ?? '';
      _city.text = profile?.homeCity ?? '';
      _operatorId = profile?.preferredOperator;
      _favourites = favourites;
      _initialised = true;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().saveProfile(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            homeCity: _city.text.trim(),
            preferredOperator: _operatorId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set a new password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.length < 8) return;
    try {
      await context.read<AuthService>().updatePassword(controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!_initialised) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.trackNavy,
                child: Text(
                  (auth.profile?.displayName ?? 'C')
                      .characters
                      .first
                      .toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.profile?.displayName ?? 'Commuter',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      auth.user?.email ?? auth.user?.phone ?? '',
                      style: const TextStyle(color: AppTheme.slate, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Home city',
              hintText: 'Kuala Lumpur, Johor Bahru, George Town…',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _operatorId,
            decoration: const InputDecoration(
              labelText: 'Preferred operator',
              prefixIcon: Icon(Icons.commute_outlined),
            ),
            items: [
              for (final op in Operators.all)
                DropdownMenuItem(value: op.id, child: Text(op.shortName)),
            ],
            onChanged: (v) => setState(() => _operatorId = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.password_outlined),
            label: const Text('Change password'),
          ),
          const SizedBox(height: 28),
          const Text('Saved stops',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          if (_favourites.isEmpty)
            const Text(
              'Tap the star on any stop to keep it here.',
              style: TextStyle(color: AppTheme.slate),
            )
          else
            for (final f in _favourites)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.star, color: AppTheme.hibiscus),
                  title: Text(f.stopName),
                  subtitle: Text(Operators.byId(f.operatorId).shortName),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await context
                          .read<AuthService>()
                          .removeFavourite(f.stopId);
                      await _hydrate();
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
