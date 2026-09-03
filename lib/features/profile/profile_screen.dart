import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/transit_repository.dart';
import '../../widgets/status_banner.dart';
import '../auth/auth_service.dart';
import '../auth/auth_validators.dart';
import '../stop/stop_detail_screen.dart';
import 'profile_edit_controller.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/profile_fields.dart';
import 'widgets/profile_header.dart';
import 'widgets/saved_stop_card.dart';
import 'widgets/theme_mode_selector.dart';

/// MODULE 4 (d) — manage profile information.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.editController,
  });

  final ProfileEditController? editController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();

  String? _operatorId;
  bool _busy = false;
  bool _initialised = false;
  bool _trackingEdits = false;
  String? _error;

  late final ProfileEditController _editController;
  late final bool _ownsEditController;

  String _originalName = '';
  String _originalPhone = '';
  String _originalCity = '';
  String? _originalOperatorId;

  @override
  void initState() {
    super.initState();
    _ownsEditController = widget.editController == null;
    _editController = widget.editController ?? ProfileEditController();
    _editController.attachDiscard(_restoreOriginalValues);

    _name.addListener(_syncDirtyState);
    _phone.addListener(_syncDirtyState);
    _city.addListener(_syncDirtyState);

    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  @override
  void dispose() {
    _name.removeListener(_syncDirtyState);
    _phone.removeListener(_syncDirtyState);
    _city.removeListener(_syncDirtyState);
    _editController.detachDiscard();
    if (_ownsEditController) {
      _editController.dispose();
    }

    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  void _captureOriginalValues() {
    _originalName = _name.text.trim();
    _originalPhone = _phone.text.trim();
    _originalCity = _city.text.trim();
    _originalOperatorId = _operatorId;
    _editController.setDirty(false);
  }

  void _syncDirtyState() {
    if (!_trackingEdits || !_initialised) return;

    final dirty =
        _name.text.trim() != _originalName ||
        _phone.text.trim() != _originalPhone ||
        _city.text.trim() != _originalCity ||
        _operatorId != _originalOperatorId;

    _editController.setDirty(dirty);
  }

  void _restoreOriginalValues() {
    if (!mounted) return;

    _trackingEdits = false;
    setState(() {
      _name.text = _originalName;
      _phone.text = _originalPhone;
      _city.text = _originalCity;
      _operatorId = _originalOperatorId;
      _error = null;
    });
    _trackingEdits = true;
    _editController.setDirty(false);
  }

  Future<void> _hydrate() async {
    final auth = context.read<AuthService>();
    setState(() => _error = null);

    try {
      await auth.refreshProfile();
      await auth.refreshFavourites();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Profile data could not be refreshed. Cached account details are still available.';
        });
      }
    }

    if (!mounted) return;
    final profile = auth.profile;
    final metadataName = auth.user?.userMetadata?['full_name'] as String?;

    _trackingEdits = false;
    setState(() {
      _name.text = profile?.fullName ?? metadataName ?? '';
      _phone.text = profile?.phone ?? '';
      _city.text = profile?.homeCity ?? '';
      _operatorId = profile?.preferredOperator;
      _initialised = true;
    });
    _captureOriginalValues();
    _trackingEdits = true;
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.saveProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        homeCity: _city.text.trim(),
        preferredOperator: _operatorId,
      );

      if (!mounted) return;
      _captureOriginalValues();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final newPassword = await showChangePasswordDialog(context);
    if (!mounted || newPassword == null) return;

    try {
      await context.read<AuthService>().updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthValidators.friendlyError(e));
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          _editController.isDirty
              ? 'Unsaved profile changes will be discarded. You can sign in again at any time.'
              : 'You can sign in again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  Future<void> _openFavourite(FavouriteStop favourite) async {
    final repository = context.read<TransitRepository>();
    final stop = await repository.getStop(
      favourite.operatorId,
      favourite.stopId,
    );

    if (!mounted) return;

    if (stop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${favourite.stopName} is not available offline. Download ${Operators.byId(favourite.operatorId).shortName} data first.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StopDetailScreen(stop: stop)),
    );
  }

  Future<void> _removeFavourite(FavouriteStop favourite) async {
    try {
      await context.read<AuthService>().removeFavourite(favourite.stopId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove favourite: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final favourites = auth.favourites;
    final metadataName = auth.user?.userMetadata?['full_name'] as String?;
    final displayName = auth.profile?.fullName?.trim().isNotEmpty == true
        ? auth.profile!.fullName!.trim()
        : (metadataName?.trim().isNotEmpty == true
            ? metadataName!.trim()
            : 'Commuter');

    if (!_initialised) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _busy ? null : _confirmSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _hydrate,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            ProfileHeader(
              displayName: displayName,
              accountLabel: auth.user?.email ?? auth.user?.phone ?? '',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              StatusBanner(
                message: _error!,
                color: AppTheme.hibiscus,
                icon: Icons.error_outline,
              ),
            ],
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: ProfileFields(
                nameController: _name,
                phoneController: _phone,
                cityController: _city,
                operatorId: _operatorId,
                enabled: !_busy,
                onOperatorChanged: (value) {
                  setState(() => _operatorId = value);
                  _syncDirtyState();
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving...' : 'Save changes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _changePassword,
              icon: const Icon(Icons.password_outlined),
              label: const Text('Change password'),
            ),
            const SizedBox(height: 18),
            const ThemeModeSelector(),
            const SizedBox(height: 28),
            const Text(
              'Saved stops',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (favourites.isEmpty)
              const Text(
                'Tap the star on any stop to keep it here.',
                style: TextStyle(color: AppTheme.slate),
              )
            else
              for (final favourite in favourites)
                SavedStopCard(
                  favourite: favourite,
                  onOpen: () => _openFavourite(favourite),
                  onRemove: () => _removeFavourite(favourite),
                ),
          ],
        ),
      ),
    );
  }
}
