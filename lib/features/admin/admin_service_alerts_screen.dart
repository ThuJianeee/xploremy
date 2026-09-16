import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import 'admin_management_service.dart';

class AdminServiceAlertsScreen extends StatefulWidget {
  const AdminServiceAlertsScreen({super.key});

  @override
  State<AdminServiceAlertsScreen> createState() =>
      _AdminServiceAlertsScreenState();
}

class _AdminServiceAlertsScreenState extends State<AdminServiceAlertsScreen> {
  final AdminManagementService _service = AdminManagementService();
  bool _loading = true;
  String? _error;
  List<AdminServiceAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final alerts = await _service.alerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Service alerts could not be loaded. Apply the latest Supabase SQL and confirm this account is an admin.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([AdminServiceAlert? alert]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminServiceAlertEditorScreen(alert: alert),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(AdminServiceAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete service alert?'),
        content: Text('Delete "${alert.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteAlert(alert.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this service alert.')),
      );
    }
  }

  String _operatorName(String? id) {
    if (id == null || id.isEmpty) return 'All operators';
    return Operators.byId(id).shortName;
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · Service alerts'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Create alert'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      if (_alerts.isEmpty)
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.notifications_none),
                            title: Text('No service alerts'),
                            subtitle: Text(
                                'Create an alert to publish it to XploreMY users.'),
                          ),
                        )
                      else
                        for (final alert in _alerts)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alert.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          alert.isActive
                                              ? 'ACTIVE'
                                              : 'INACTIVE',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_operatorName(alert.operatorId)} · ${alert.severity.toUpperCase()}',
                                    style: const TextStyle(
                                      color: AppTheme.slate,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(alert.body),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Starts ${_timeLabel(alert.startsAt)}${alert.endsAt == null ? ' · No end time' : ' · Ends ${_timeLabel(alert.endsAt!)}'}',
                                    style: const TextStyle(
                                      color: AppTheme.slate,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _openEditor(alert),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _delete(alert),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class AdminServiceAlertEditorScreen extends StatefulWidget {
  const AdminServiceAlertEditorScreen({super.key, this.alert});

  final AdminServiceAlert? alert;

  @override
  State<AdminServiceAlertEditorScreen> createState() =>
      _AdminServiceAlertEditorScreenState();
}

class _AdminServiceAlertEditorScreenState
    extends State<AdminServiceAlertEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminManagementService _service = AdminManagementService();
  late final TextEditingController _title;
  late final TextEditingController _body;
  String _operatorValue = 'all';
  String _severity = 'info';
  late DateTime _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    _title = TextEditingController(text: alert?.title ?? '');
    _body = TextEditingController(text: alert?.body ?? '');
    _operatorValue = alert?.operatorId ?? 'all';
    _severity = alert?.severity ?? 'info';
    _startsAt = alert?.startsAt.toLocal() ?? DateTime.now();
    _endsAt = alert?.endsAt?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _timeLabel(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endsAt != null && !_endsAt!.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after the start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final alert = widget.alert;
      if (alert == null) {
        await _service.createAlert(
          operatorId: _operatorValue == 'all' ? null : _operatorValue,
          title: _title.text,
          body: _body.text,
          severity: _severity,
          startsAt: _startsAt,
          endsAt: _endsAt,
        );
      } else {
        await _service.updateAlert(
          alertId: alert.id,
          operatorId: _operatorValue == 'all' ? null : _operatorValue,
          title: _title.text,
          body: _body.text,
          severity: _severity,
          startsAt: _startsAt,
          endsAt: _endsAt,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this service alert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alert == null
            ? 'Create service alert'
            : 'Edit service alert'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _body,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _operatorValue,
              decoration: const InputDecoration(labelText: 'Affected operator'),
              items: [
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('All operators'),
                ),
                for (final operator in Operators.all)
                  DropdownMenuItem<String>(
                    value: operator.id,
                    child: Text(operator.shortName),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _operatorValue = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'warning', child: Text('Warning')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _severity = value);
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Start time'),
                    subtitle: Text(_timeLabel(_startsAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final value = await _pickDateTime(_startsAt);
                      if (value != null && mounted) {
                        setState(() => _startsAt = value);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: const Text('End time'),
                    subtitle: Text(
                      _endsAt == null ? 'No end time' : _timeLabel(_endsAt!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_endsAt != null)
                          IconButton(
                            tooltip: 'Remove end time',
                            onPressed: () => setState(() => _endsAt = null),
                            icon: const Icon(Icons.clear),
                          ),
                        const Icon(Icons.edit_calendar_outlined),
                      ],
                    ),
                    onTap: () async {
                      final value = await _pickDateTime(
                        _endsAt ?? _startsAt.add(const Duration(hours: 2)),
                      );
                      if (value != null && mounted) {
                        setState(() => _endsAt = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save alert'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
