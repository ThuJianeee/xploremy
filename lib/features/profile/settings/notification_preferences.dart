import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.serviceAlerts = true,
    this.journeyReminders = true,
    this.departureReminders = true,
    this.rewardUpdates = true,
    this.dataFreshnessAlerts = true,
    this.reminderLeadMinutes = 10,
  });

  final bool serviceAlerts;
  final bool journeyReminders;
  final bool departureReminders;
  final bool rewardUpdates;
  final bool dataFreshnessAlerts;
  final int reminderLeadMinutes;

  NotificationPreferences copyWith({
    bool? serviceAlerts,
    bool? journeyReminders,
    bool? departureReminders,
    bool? rewardUpdates,
    bool? dataFreshnessAlerts,
    int? reminderLeadMinutes,
  }) {
    return NotificationPreferences(
      serviceAlerts: serviceAlerts ?? this.serviceAlerts,
      journeyReminders: journeyReminders ?? this.journeyReminders,
      departureReminders: departureReminders ?? this.departureReminders,
      rewardUpdates: rewardUpdates ?? this.rewardUpdates,
      dataFreshnessAlerts: dataFreshnessAlerts ?? this.dataFreshnessAlerts,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'service_alerts': serviceAlerts,
        'journey_reminders': journeyReminders,
        'departure_reminders': departureReminders,
        'reward_updates': rewardUpdates,
        'data_freshness_alerts': dataFreshnessAlerts,
        'reminder_lead_minutes': reminderLeadMinutes,
      };

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      serviceAlerts: map['service_alerts'] != false,
      journeyReminders: map['journey_reminders'] != false,
      departureReminders: map['departure_reminders'] != false,
      rewardUpdates: map['reward_updates'] != false,
      dataFreshnessAlerts: map['data_freshness_alerts'] != false,
      reminderLeadMinutes:
          (map['reminder_lead_minutes'] as num?)?.toInt() ?? 10,
    );
  }
}

class NotificationPreferencesStore {
  NotificationPreferencesStore._();

  static String _key(String userId) => 'xploremy_notification_prefs_v1_$userId';

  static Future<NotificationPreferences> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  static Future<void> save(
    String userId,
    NotificationPreferences value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(value.toMap()));
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
