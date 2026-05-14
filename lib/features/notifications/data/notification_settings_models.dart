// Mirror of GET /api/mobile/notifications/settings (v87).
//
// The full backend payload is rich (channels, sections, rules, …). The
// mobile editor we ship in v87 focuses on the **safe-to-toggle** subset:
//
//   * channels.{telegram,sms}.enabled       — global on/off per channel
//   * per-section `*_enabled` checkboxes    — master switch for each
//                                             notification family
//
// Provider credentials (telegram bot token, sms api key/url, …) are
// **never** parsed into Flutter — they stay backend-only.

class NotificationChannelStatus {
  NotificationChannelStatus({
    required this.enabled,
    required this.configured,
  });

  factory NotificationChannelStatus.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return NotificationChannelStatus(
      enabled: j['enabled'] == true,
      configured: j['configured'] == true,
    );
  }

  final bool enabled;

  /// Server-side: `true` when the channel has the required credentials
  /// stored. We surface this as a read-only badge so the user knows why a
  /// channel toggle may have no effect.
  final bool configured;
}

/// One togglable section. The backend's section payload has many fields
/// (schedule, thresholds, includes, …), but we only surface the master
/// `*_enabled` checkbox in the v87 editor so the UI stays scannable.
class NotificationSectionSwitch {
  NotificationSectionSwitch({
    required this.sectionId,
    required this.enabledKey,
    required this.enabled,
  });

  /// Section id as it appears in the backend payload (`periodic_day`,
  /// `weather`, …).
  final String sectionId;

  /// Setting key the PATCH endpoint expects (`periodic_day_enabled`, …).
  final String enabledKey;

  final bool enabled;
}

class NotificationSettingsSnapshot {
  NotificationSettingsSnapshot({
    required this.scope,
    required this.scopeNote,
    required this.notificationsMasterEnabled,
    required this.telegram,
    required this.sms,
    required this.push,
    required this.sectionSwitches,
  });

  factory NotificationSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final channels =
        (json['channels'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final sectionsJson =
        (json['sections'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    bool? readSectionBool(String sectionId, String key) {
      final section =
          (sectionsJson[sectionId] as Map?)?.cast<String, dynamic>();
      if (section == null) return null;
      final settings =
          (section['settings'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final v = settings[key];
      if (v is bool) return v;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      return null;
    }

    bool master = false;
    final generalSection =
        (sectionsJson['general'] as Map?)?.cast<String, dynamic>();
    if (generalSection != null) {
      final settings =
          (generalSection['settings'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      final v = settings['notifications_enabled'];
      master = v == true || v == 'true';
    }

    final switches = <NotificationSectionSwitch>[];
    void addSwitch(String sectionId, String key) {
      final v = readSectionBool(sectionId, key);
      if (v == null) return;
      switches.add(NotificationSectionSwitch(
        sectionId: sectionId,
        enabledKey: key,
        enabled: v,
      ));
    }

    addSwitch('periodic_day', 'periodic_day_enabled');
    addSwitch('periodic_night', 'periodic_night_enabled');
    addSwitch('sunset', 'pre_sunset_enabled');
    addSwitch('discharge', 'night_discharge_enabled');
    addSwitch('load', 'load_alert_enabled');
    addSwitch('weather', 'weather_test_enabled');
    addSwitch('battery', 'battery_test_enabled');
    addSwitch('daily_report', 'daily_report_enabled');

    return NotificationSettingsSnapshot(
      scope: (json['scope'] ?? '').toString(),
      scopeNote: (json['scope_note'] ?? '').toString(),
      notificationsMasterEnabled: master,
      telegram: NotificationChannelStatus.fromJson(
        (channels['telegram'] as Map?)?.cast<String, dynamic>(),
      ),
      sms: NotificationChannelStatus.fromJson(
        (channels['sms'] as Map?)?.cast<String, dynamic>(),
      ),
      // v101 Phase D — push channel. `enabled` reflects the master
      // `push_enabled` toggle the user controls from Settings;
      // `configured` is true once the mobile app has registered at
      // least one FCM token for this user.
      push: NotificationChannelStatus.fromJson(
        (channels['push'] as Map?)?.cast<String, dynamic>(),
      ),
      sectionSwitches: switches,
    );
  }

  /// `'global'` or `'per_device'` (server says global today).
  final String scope;
  final String scopeNote;
  final bool notificationsMasterEnabled;
  final NotificationChannelStatus telegram;
  final NotificationChannelStatus sms;
  final NotificationChannelStatus push;
  final List<NotificationSectionSwitch> sectionSwitches;
}
