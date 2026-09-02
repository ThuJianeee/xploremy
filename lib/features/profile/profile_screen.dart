import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/transit_repository.dart';
import '../auth/auth_service.dart';
import '../stop/stop_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _hydrate(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();

    super.dispose();
  }

  // --------------------------------------------------------------- hydrate

  Future<void> _hydrate() async {
    final auth = context.read<AuthService>();

    try {
      await auth.refreshProfile();
      await auth.refreshFavourites();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final profile = auth.profile;

    setState(() {
      _name.text = profile?.fullName ?? '';
      _phone.text = profile?.phone ?? '';
      _city.text = profile?.homeCity ?? '';
      _operatorId = profile?.preferredOperator;

      _initialised = true;
    });
  }

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    final auth = context.read<AuthService>();

    setState(() {
      _busy = true;
    });

    try {
      await auth.saveProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        homeCity: _city.text.trim(),
        preferredOperator: _operatorId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // -------------------------------------------------------- password change

  Future<void> _changePassword() async {
    final controller = TextEditingController();

    // Get AuthService BEFORE any await.
    final auth = context.read<AuthService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Set a new password',
          ),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Update',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      controller.dispose();
      return;
    }

    if (confirmed != true) {
      controller.dispose();
      return;
    }

    if (controller.text.length < 8) {
      controller.dispose();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 8 characters',
          ),
        ),
      );

      return;
    }

    try {
      await auth.updatePassword(
        controller.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ---------------------------------------------------------- saved stop

  Future<void> _openFavourite(
      FavouriteStop favourite,
      ) async {
    final repository = context.read<TransitRepository>();

    final stop = await repository.getStop(
      favourite.operatorId,
      favourite.stopId,
    );

    if (!mounted) {
      return;
    }

    if (stop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${favourite.stopName} is not available offline. '
                'Download ${Operators.byId(favourite.operatorId).shortName} data first.',
          ),
        ),
      );

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          stop: stop,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final favourites = auth.favourites;

    if (!_initialised) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: auth.signOut,
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _hydrate,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),

          children: [
            // =========================================================
            // PROFILE HEADER
            // =========================================================

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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.profile?.displayName ??
                            'Commuter',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        auth.user?.email ??
                            auth.user?.phone ??
                            '',
                        style: const TextStyle(
                          color: AppTheme.slate,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 24,
            ),

            // =========================================================
            // FULL NAME
            // =========================================================

            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                ),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // =========================================================
            // CONTACT NUMBER
            // =========================================================

            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact number',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // =========================================================
            // HOME CITY
            // =========================================================

            TextField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Home city',
                hintText:
                'Kuala Lumpur, Johor Bahru, George Town…',
                prefixIcon: Icon(
                  Icons.location_city_outlined,
                ),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // =========================================================
            // PREFERRED OPERATOR
            // =========================================================

            DropdownButtonFormField<String>(
              initialValue: _operatorId,
              decoration: const InputDecoration(
                labelText: 'Preferred operator',
                prefixIcon: Icon(
                  Icons.commute_outlined,
                ),
              ),

              items: [
                for (final op in Operators.all)
                  DropdownMenuItem<String>(
                    value: op.id,
                    child: Text(
                      op.shortName,
                    ),
                  ),
              ],

              onChanged: (value) {
                setState(() {
                  _operatorId = value;
                });
              },
            ),

            const SizedBox(
              height: 24,
            ),

            // =========================================================
            // SAVE BUTTON
            // =========================================================

            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Saving...'
                    : 'Save changes',
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // =========================================================
            // CHANGE PASSWORD
            // =========================================================

            OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(
                Icons.password_outlined,
              ),
              label: const Text(
                'Change password',
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // =========================================================
            // SAVED STOPS
            // =========================================================

            const Text(
              'Saved stops',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // =========================================================
            // EMPTY SAVED STOPS
            // =========================================================

            if (favourites.isEmpty)
              const Text(
                'Tap the star on any stop to keep it here.',
                style: TextStyle(
                  color: AppTheme.slate,
                ),
              )

            // =========================================================
            // SAVED STOP LIST
            // =========================================================

            else
              for (final favourite in favourites)
                Card(
                  margin: const EdgeInsets.only(
                    bottom: 8,
                  ),

                  child: ListTile(
                    leading: const Icon(
                      Icons.star,
                      color: AppTheme.hibiscus,
                    ),

                    title: Text(
                      favourite.stopName,
                    ),

                    subtitle: Text(
                      Operators.byId(
                        favourite.operatorId,
                      ).shortName,
                    ),

                    // Tap saved stop to open Stop Detail.
                    onTap: () {
                      _openFavourite(
                        favourite,
                      );
                    },

                    // Remove favourite.
                    trailing: Builder(
                      builder: (tileContext) {
                        return IconButton(
                          tooltip: 'Remove favourite',
                          icon: const Icon(
                            Icons.close,
                          ),

                          onPressed: () async {
                            // Obtain everything that uses
                            // BuildContext BEFORE the await.
                            final authService =
                            tileContext.read<AuthService>();

                            final messenger =
                            ScaffoldMessenger.of(
                              tileContext,
                            );

                            try {
                              await authService
                                  .removeFavourite(
                                favourite.stopId,
                              );
                            } catch (e) {
                              if (!mounted) {
                                return;
                              }

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not remove: $e',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}