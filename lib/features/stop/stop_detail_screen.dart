import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/geo.dart';
import '../../core/station_names.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/transit_repository.dart';
import '../../widgets/status_banner.dart';
import '../auth/auth_service.dart';
import '../rewards/rewards_store.dart';
import '../reviews/stop_reviews_service.dart';
import 'trip_timetable_screen.dart';

part 'widgets/departure_tile.dart';

class StopDetailScreen extends StatefulWidget {
  const StopDetailScreen({super.key, required this.stop});

  final GtfsStop stop;

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  List<Departure> _departures = const [];
  List<GtfsStop> _shape = const [];
  List<VehiclePosition> _vehicles = const [];
  bool _loading = true;
  bool _isFavourite = false;
  DateTime? _updatedAt;
  DateTime? _staticUpdatedAt;
  DateTime? _realtimeUpdatedAt;
  ServiceActivityLevel? _activity;
  ServiceSpan? _serviceSpan;
  String? _error;
  bool _refreshing = false;
  Timer? _ticker;
  String? _routeFilter;
  String? _selectedTripId;
  DateTime? _futureAt;

  final StopReviewsService _reviewsService = StopReviewsService();
  List<StopReview> _reviews = const [];
  bool _reviewsLoading = true;
  String? _reviewsError;

  @override
  void initState() {
    super.initState();
    RewardsStore.incrementMission('stop_opened');
    _load();
    _loadReviews();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_futureAt == null) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<Departure> get _visibleDepartures {
    final filter = _routeFilter;
    if (filter == null) return _departures;
    return _departures.where((d) => d.routeId == filter).toList();
  }

  Departure? get _selectedDeparture {
    final selectedId = _selectedTripId;
    if (selectedId == null) return null;
    for (final departure in _departures) {
      if (departure.tripId == selectedId) return departure;
    }
    return null;
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final repo = context.read<TransitRepository>();
    final auth = context.read<AuthService>();
    final reference = _futureAt ?? DateTime.now();

    try {
      final departures = await repo.getDeparturesForStop(
        operatorId: widget.stop.operatorId,
        stopId: widget.stop.stopId,
        after: reference,
        limit: 30,
      );

      final activeRoute = _routeFilter;
      final preferred = departures
          .where((d) => activeRoute == null || d.routeId == activeRoute)
          .toList();
      Departure? selectedDeparture;
      if (preferred.isNotEmpty) {
        for (final departure in preferred) {
          if (departure.tripId == _selectedTripId) {
            selectedDeparture = departure;
            break;
          }
        }
        selectedDeparture ??= preferred.first;
      } else if (departures.isNotEmpty) {
        selectedDeparture = departures.first;
      }

      List<GtfsStop> shape = const [];
      if (selectedDeparture != null) {
        shape = await repo.tripShape(
            widget.stop.operatorId, selectedDeparture.tripId);
      }

      final vehicles = _futureAt == null && selectedDeparture != null
          ? await repo.relevantVehicles(
              operatorId: widget.stop.operatorId,
              tripId: selectedDeparture.tripId,
              routeId: selectedDeparture.routeId,
              nearStop: widget.stop,
            )
          : const <VehiclePosition>[];

      final activity = await repo.serviceActivityLevel(
          widget.stop.operatorId, widget.stop.stopId);
      final serviceSpan = await repo.serviceSpanForStop(
        operatorId: widget.stop.operatorId,
        stopId: widget.stop.stopId,
        date: reference,
      );
      final staticUpdated = await repo.lastSync(widget.stop.operatorId);
      final realtimeUpdated = repo.realtimeFetchedAt(widget.stop.operatorId);

      var favourite = false;
      if (auth.isSignedIn) {
        try {
          final favourites = await auth.favouriteStops();
          favourite = favourites.any((item) =>
              item.stopId == widget.stop.stopId &&
              item.operatorId == widget.stop.operatorId);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _departures = departures;
        _shape = shape;
        _vehicles = vehicles;
        _activity = activity;
        _serviceSpan = serviceSpan;
        _isFavourite = favourite;
        _staticUpdatedAt = staticUpdated;
        _realtimeUpdatedAt = realtimeUpdated;
        _updatedAt = DateTime.now();
        if (departures.isNotEmpty && _selectedTripId == null) {
          _selectedTripId = selectedDeparture?.tripId;
        }
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Stop information could not be refreshed. Pull down to try again.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _selectDeparture(Departure departure) async {
    setState(() => _selectedTripId = departure.tripId);
    final repo = context.read<TransitRepository>();
    final shape =
        await repo.tripShape(widget.stop.operatorId, departure.tripId);
    final vehicles = _futureAt == null
        ? await repo.relevantVehicles(
            operatorId: widget.stop.operatorId,
            tripId: departure.tripId,
            routeId: departure.routeId,
            nearStop: widget.stop,
          )
        : const <VehiclePosition>[];
    if (!mounted) return;
    setState(() {
      _shape = shape;
      _vehicles = vehicles;
      _realtimeUpdatedAt = repo.realtimeFetchedAt(widget.stop.operatorId);
    });
  }

  Future<void> _openTripTimetable() async {
    final departure = _selectedDeparture;
    if (departure == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripTimetableScreen(
          departure: departure,
          currentStopId: widget.stop.stopId,
        ),
      ),
    );
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _reviewsLoading = true;
        _reviewsError = null;
      });
    }
    try {
      final reviews = await _reviewsService.list(
        operatorId: widget.stop.operatorId,
        stopId: widget.stop.stopId,
      );
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewsError =
            'Ratings are not available yet. Apply the enhanced Supabase SQL to enable stop ratings and comments.';
        _reviewsLoading = false;
      });
    }
  }

  Future<void> _openReviewEditor([StopReview? existing]) async {
    if (existing != null && !existing.canOwnerEdit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only pending reviews can be edited. Delete this review and submit a new one instead.',
          ),
        ),
      );
      return;
    }

    final result = await showDialog<_ReviewEditorResult>(
      context: context,
      builder: (_) => _ReviewEditorDialog(existing: existing),
    );
    if (!mounted || result == null) return;

    try {
      final auth = context.read<AuthService>();
      final metadataName = auth.user?.userMetadata?['full_name'] as String?;
      final displayName =
          auth.profile?.displayName ?? metadataName ?? 'Commuter';

      if (existing == null) {
        await _reviewsService.create(
          operatorId: widget.stop.operatorId,
          stopId: widget.stop.stopId,
          rating: result.rating,
          comment: result.comment,
          displayName: displayName,
        );
      } else {
        await _reviewsService.updateOwn(
          reviewId: existing.id,
          rating: result.rating,
          comment: result.comment,
          displayName: displayName,
        );
      }

      await _loadReviews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Review submitted for admin approval.'
                : 'Review updated and sent for admin approval again.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save the review. Make sure the latest Supabase SQL is applied. ($error)',
          ),
        ),
      );
    }
  }

  Future<void> _deleteReview(StopReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this review?'),
        content: const Text(
          'This removes this review permanently. Your other reviews at this stop are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _reviewsService.deleteOwn(review.id);
      await _loadReviews();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the review.')),
      );
    }
  }

  Future<void> _reportReview(StopReview review) async {
    const reasons = <String>[
      'Spam or advertising',
      'Abusive or offensive content',
      'False or misleading information',
      'Not related to this stop',
      'Other',
    ];
    var reason = reasons.first;
    var detailsText = '';

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: [
                    for (final value in reasons)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 3,
                  maxLength: 300,
                  onChanged: (value) => detailsText = value,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );

    if (submit != true || !mounted) return;

    try {
      await _reviewsService.report(
        reviewId: review.id,
        reason: reason,
        details: detailsText.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted for admin review.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the report. Please try again.'),
        ),
      );
    }
  }

  Future<void> _pickFutureDeparture() async {
    final now = DateTime.now();
    final initial =
        _futureAt != null && _futureAt!.isAfter(now) ? _futureAt! : now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      _futureAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _selectedTripId = null;
    });
    await _load();
  }

  Future<void> _toggleFavourite() async {
    final auth = context.read<AuthService>();
    try {
      if (_isFavourite) {
        await auth.removeFavourite(widget.stop.stopId);
      } else {
        await auth.addFavourite(
            stopId: widget.stop.stopId,
            stopName: widget.stop.name,
            operatorId: widget.stop.operatorId);
      }
      if (mounted) setState(() => _isFavourite = !_isFavourite);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update favourite. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = Operators.byId(widget.stop.operatorId);
    final visible = _visibleDepartures;

    return Scaffold(
      appBar: AppBar(
        title: Text(cleanStationName(widget.stop.name)),
        actions: [
          IconButton(
              tooltip: 'Future departure',
              icon: const Icon(Icons.event_outlined),
              onPressed: _pickFutureDeparture),
          IconButton(
              tooltip: _isFavourite ? 'Remove favourite' : 'Save stop',
              icon: Icon(_isFavourite ? Icons.star : Icons.star_border),
              onPressed: _toggleFavourite),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  if (_error != null) ...[
                    StatusBanner(
                        message: _error!,
                        color: AppTheme.hibiscus,
                        icon: Icons.error_outline),
                    const SizedBox(height: 12),
                  ],
                  _header(op),
                  const SizedBox(height: 12),
                  SizedBox(height: 220, child: _map()),
                  const SizedBox(height: 12),
                  _freshnessCard(op),
                  const SizedBox(height: 18),
                  _departureHeader(),
                  const SizedBox(height: 8),
                  _departureFilters(),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No upcoming departures match this time/filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.slate)),
                    )
                  else
                    for (final d in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DepartureTile(
                          departure: d,
                          selected: d.tripId == _selectedTripId,
                          onTap: () => _selectDeparture(d),
                        ),
                      ),
                  if (_shape.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _routeTimeline(),
                  ],
                  if (op.hasRealtime) ...[
                    const SizedBox(height: 18),
                    _vehicleDetails(),
                  ],
                  const SizedBox(height: 20),
                  _reviewsSection(),
                ],
              ),
            ),
    );
  }

  Widget _header(Operator op) {
    final span = _serviceSpan;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(op.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.trackNavy)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(
                icon: Icons.event_available_outlined,
                label: 'Official GTFS timetable',
                color: AppTheme.onTime),
            _pill(
                icon: op.hasRealtime ? Icons.sensors : Icons.schedule,
                label: op.hasRealtime
                    ? '${_vehicles.length} relevant vehicles'
                    : 'Scheduled data only',
                color: op.hasRealtime ? AppTheme.signalTeal : AppTheme.slate),
            if (_activity != null)
              _pill(
                  icon: Icons.insights_outlined,
                  label: 'Service activity: ${_activity!.label}',
                  color: AppTheme.delayed),
          ]),
          if (span != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _serviceTime(
                      Icons.first_page, 'First service', span.firstAt)),
              const SizedBox(width: 10),
              Expanded(
                  child: _serviceTime(
                      Icons.last_page, 'Last service', span.lastAt)),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _serviceTime(IconData icon, String label, DateTime date) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppTheme.trackNavy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.trackNavy),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.slate)),
                Text(formatClockTime(date),
                    style: const TextStyle(fontWeight: FontWeight.w700))
              ]))
        ]),
      );

  Widget _pill(
          {required IconData icon,
          required String label,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12.5, fontWeight: FontWeight.w600))
        ]),
      );

  Widget _freshnessCard(Operator op) {
    String age(DateTime? date) {
      if (date == null) return 'Unavailable';
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return '${diff.inSeconds.clamp(0, 59)}s ago';
    }

    return Card(
        child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(Icons.update_outlined, color: AppTheme.signalTeal),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                'Data freshness\nStatic: ${age(_staticUpdatedAt)} · Realtime: ${op.hasRealtime ? age(_realtimeUpdatedAt) : 'not published'}',
                style: const TextStyle(fontSize: 12.5, height: 1.35))),
        if (_updatedAt != null)
          Text('Viewed\n${formatClockTime(_updatedAt!)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: AppTheme.slate)),
      ]),
    ));
  }

  Widget _departureHeader() {
    final future = _futureAt;
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(future == null ? 'Next departures' : 'Future departures',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (future != null)
          Text(
              '${future.day}/${future.month}/${future.year} · ${formatClockTime(future)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.signalTeal)),
      ])),
      if (future != null)
        TextButton.icon(
            onPressed: () async {
              setState(() {
                _futureAt = null;
                _selectedTripId = null;
              });
              await _load();
            },
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Now')),
    ]);
  }

  Widget _departureFilters() {
    final routes = <String, String>{};
    for (final d in _departures) {
      routes[d.routeId] = d.routeLabel;
    }
    if (routes.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
                label: const Text('All routes'),
                selected: _routeFilter == null,
                onSelected: (_) {
                  setState(() {
                    _routeFilter = null;
                    _selectedTripId = null;
                  });
                  _load(quiet: true);
                })),
        for (final entry in routes.entries)
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: _routeFilter == entry.key,
                onSelected: (selected) {
                  setState(() {
                    _routeFilter = selected ? entry.key : null;
                    _selectedTripId = null;
                  });
                  _load(quiet: true);
                },
              )),
      ]),
    );
  }

  Widget _routeTimeline() {
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.alt_route, color: AppTheme.trackNavy),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Route timeline',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          TextButton.icon(
            onPressed: _selectedDeparture == null ? null : _openTripTimetable,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('Timetable'),
          ),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < _shape.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 26,
                child: Column(children: [
                  Icon(
                      _shape[i].stopId == widget.stop.stopId
                          ? Icons.radio_button_checked
                          : Icons.circle,
                      size: _shape[i].stopId == widget.stop.stopId ? 18 : 10,
                      color: _shape[i].stopId == widget.stop.stopId
                          ? AppTheme.hibiscus
                          : AppTheme.signalTeal),
                  if (i != _shape.length - 1)
                    Container(
                        width: 2,
                        height: 26,
                        color: AppTheme.signalTeal.withValues(alpha: 0.35)),
                ])),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(cleanStationName(_shape[i].name),
                        style: TextStyle(
                            fontWeight: _shape[i].stopId == widget.stop.stopId
                                ? FontWeight.w700
                                : FontWeight.w400)))),
          ]),
      ]),
    ));
  }

  Widget _reviewsSection() {
    final approved = _reviews.where((review) => review.isApproved).toList();
    final currentUserId = _reviewsService.currentUserId;
    final ownReviews = currentUserId == null
        ? <StopReview>[]
        : _reviews.where((review) => review.userId == currentUserId).toList();
    final nonPublicOwn =
        ownReviews.where((review) => !review.isApproved).toList();

    final latestRatingByUser = <String, StopReview>{};
    for (final review in approved) {
      final previous = latestRatingByUser[review.userId];
      if (previous == null || review.updatedAt.isAfter(previous.updatedAt)) {
        latestRatingByUser[review.userId] = review;
      }
    }
    final ratingReviews = latestRatingByUser.values.toList();
    final ratingCount = ratingReviews.length;
    final average = ratingCount == 0
        ? 0.0
        : ratingReviews.fold<int>(0, (sum, review) => sum + review.rating) /
            ratingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Stop ratings & comments',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            TextButton.icon(
              onPressed:
                  _reviewsError != null ? null : () => _openReviewEditor(),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Write review'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_reviewsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviewsError != null)
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.info_outline, color: AppTheme.signalTeal),
              title: const Text('Ratings unavailable'),
              subtitle: Text(_reviewsError!),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: _loadReviews,
                icon: const Icon(Icons.refresh),
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    ratingCount == 0 ? '—' : average.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ratingCount == 0
                          ? 'No approved ratings yet'
                          : '/ 5 · $ratingCount reviewer${ratingCount == 1 ? '' : 's'} · ${approved.length} approved comment${approved.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppTheme.slate),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (nonPublicOwn.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Your non-public reviews (${nonPublicOwn.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final review in nonPublicOwn)
              _reviewCard(review, currentUserId: currentUserId),
          ],
          const SizedBox(height: 10),
          if (approved.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        color: AppTheme.signalTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No approved comments yet. You can write more than one review; each submission is checked by an admin before it becomes public.',
                        style: TextStyle(color: AppTheme.slate),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Top comments',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final review in approved.take(12))
              _reviewCard(review, currentUserId: currentUserId),
          ],
        ],
      ],
    );
  }

  Widget _reviewCard(
    StopReview review, {
    required String? currentUserId,
  }) {
    final isOwn = review.userId == currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _reviewTimeLabel(review.updatedAt),
                          style: const TextStyle(
                            color: AppTheme.slate,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!review.isApproved)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(review.moderationStatus),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                    ],
                  ),
                  if (isOwn || review.isApproved)
                    PopupMenuButton<String>(
                      tooltip: 'Review options',
                      onSelected: (value) {
                        if (value == 'edit') _openReviewEditor(review);
                        if (value == 'delete') _deleteReview(review);
                        if (value == 'report') _reportReview(review);
                      },
                      itemBuilder: (_) => [
                        if (isOwn && review.canOwnerEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 8),
                                Text('Edit review'),
                              ],
                            ),
                          ),
                        if (isOwn)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline),
                                SizedBox(width: 8),
                                Text('Delete review'),
                              ],
                            ),
                          ),
                        if (!isOwn && review.isApproved)
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined),
                                SizedBox(width: 8),
                                Text('Report review'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              if (review.comment.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review.comment),
              ],
              if (!review.isApproved) ...[
                const SizedBox(height: 8),
                Text(
                  review.moderationNote?.trim().isNotEmpty == true
                      ? review.moderationNote!
                      : review.isPending
                          ? 'Waiting for admin approval.'
                          : review.isRejected
                              ? 'This review was rejected by an admin.'
                              : 'This review is hidden.',
                  style: const TextStyle(color: AppTheme.slate, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _reviewTimeLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }

  Widget _vehicleDetails() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Realtime vehicle details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      if (_futureAt != null)
        const Text(
            'Realtime vehicles are hidden while viewing a future departure time.',
            style: TextStyle(color: AppTheme.slate))
      else if (_vehicles.isEmpty)
        const Text(
            'No relevant vehicle is currently matched to this stop/route. Unrelated operator vehicles are filtered out.',
            style: TextStyle(color: AppTheme.slate))
      else
        for (final vehicle in _vehicles.take(8))
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                  child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.directions_bus_outlined)),
                title: Text(
                    vehicle.vehicleId.isEmpty ? 'Vehicle' : vehicle.vehicleId),
                subtitle: Text(
                    'Route ${vehicle.routeId ?? '—'} · Trip ${vehicle.tripId ?? '—'}\n${vehicle.timestamp == null ? 'Feed timestamp unavailable' : 'Position ${_vehicleAge(vehicle.timestamp!)}'}'),
                isThreeLine: true,
                trailing: vehicle.bearing == null
                    ? null
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.navigation_outlined, size: 18),
                            Text('${vehicle.bearing!.round()}°',
                                style: const TextStyle(fontSize: 11))
                          ]),
              ))),
    ]);
  }

  String _vehicleAge(DateTime timestamp) {
    final seconds = DateTime.now().difference(timestamp).inSeconds;
    if (seconds < 60) return '${seconds.clamp(0, 59)}s ago';
    if (seconds < 3600) return '${seconds ~/ 60}m ago';
    return '${seconds ~/ 3600}h ago';
  }

  Widget _map() {
    final centre = LatLng(widget.stop.lat, widget.stop.lon);
    final line = _shape.map((s) => LatLng(s.lat, s.lon)).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        FlutterMap(
          options: MapOptions(initialCenter: centre, initialZoom: 14),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.xploremy.app'),
            if (line.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                    points: line,
                    strokeWidth: 4,
                    color: AppTheme.trackNavy.withValues(alpha: 0.7))
              ]),
            MarkerLayer(markers: [
              Marker(
                  point: centre,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: AppTheme.hibiscus, size: 36)),
              for (final v in _vehicles.take(30))
                Marker(
                    point: LatLng(v.lat, v.lon),
                    width: 24,
                    height: 24,
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppTheme.signalTeal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.directions_bus,
                            size: 13, color: Colors.white))),
            ]),
          ],
        ),
        Positioned(
            left: 7,
            bottom: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8)),
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Map legend',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87)),
                        Text('📍 Stop   ● Relevant live vehicle',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87)),
                        Text('— Selected trip timeline',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87)),
                      ])),
            )),
        Positioned(
            right: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(4)),
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Text('© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black87))),
            )),
      ]),
    );
  }
}

class _ReviewEditorResult {
  const _ReviewEditorResult({
    required this.rating,
    required this.comment,
  });

  final int rating;
  final String comment;
}

class _ReviewEditorDialog extends StatefulWidget {
  const _ReviewEditorDialog({this.existing});

  final StopReview? existing;

  @override
  State<_ReviewEditorDialog> createState() => _ReviewEditorDialogState();
}

class _ReviewEditorDialogState extends State<_ReviewEditorDialog> {
  late final TextEditingController _comment;
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _comment = TextEditingController(text: widget.existing?.comment ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _ReviewEditorResult(
        rating: _rating,
        comment: _comment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Rate this stop' : 'Edit review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating'),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              autofocus: false,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText:
                    'Share cleanliness, accessibility, crowding, or interchange experience.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 150,
          child: FilledButton(
            onPressed: _save,
            child:
                Text(widget.existing == null ? 'Submit review' : 'Save review'),
          ),
        ),
      ],
    );
  }
}
