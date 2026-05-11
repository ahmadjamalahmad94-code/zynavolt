import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/notification_settings_models.dart';
import '../data/notifications_repository.dart';

/// إعدادات الإشعارات (v87).
///
/// Surfaces a focused, safe subset of `GET /api/mobile/notifications/settings`:
/// the master `notifications_enabled` switch, channel on/off + configured
/// status, and the major per-section enabled toggles.
///
/// Every change writes through `PATCH /api/mobile/notifications/settings`
/// with the backend's allowed-key whitelist. Provider credentials
/// (bot tokens, sms keys/urls) are NEVER fetched into Flutter and have
/// no UI here.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  /// v90c: per-key optimistic overrides. A key in this map means "the user
  /// just toggled this; show the new value immediately, regardless of what
  /// the server currently says." Entries are dropped automatically once
  /// the server-side truth catches up (see `_reconcile`).
  final Map<String, bool> _optimistic = {};

  /// v90c: per-key in-flight tracking. We allow parallel PATCHes across
  /// different keys — the user can flip three switches in rapid succession
  /// and each one runs its own request without blocking the others.
  /// Re-tapping the SAME key while it's in flight is ignored.
  final Set<String> _busy = {};

  /// Throttles the success snackbar so a fast sequence of toggles shows
  /// one calm confirmation instead of stacking five.
  DateTime _lastSuccessSnack =
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Drop overrides whose server value has caught up to (or differs from)
  /// our optimistic guess. Called after every fresh fetch.
  void _reconcile(NotificationSettingsSnapshot fresh) {
    if (_optimistic.isEmpty) return;
    final next = <String, bool>{};
    bool serverMatchesOverride(String key, bool override) {
      if (key == 'notifications_enabled') {
        return fresh.notificationsMasterEnabled == override;
      }
      if (key == 'telegram_enabled') return fresh.telegram.enabled == override;
      if (key == 'sms_enabled') return fresh.sms.enabled == override;
      for (final s in fresh.sectionSwitches) {
        if (s.enabledKey == key) return s.enabled == override;
      }
      return false;
    }

    _optimistic.forEach((key, value) {
      if (!serverMatchesOverride(key, value)) {
        // Server hasn't acknowledged yet — keep the override so the
        // switch doesn't flicker back to the old value mid-flight.
        next[key] = value;
      }
    });
    if (next.length != _optimistic.length) {
      _optimistic
        ..clear()
        ..addAll(next);
    }
  }

  Future<void> _patchOne(String key, bool newValue) async {
    if (_busy.contains(key)) return;
    final previousServerValue = _readServerValue(key);
    setState(() {
      _optimistic[key] = newValue;
      _busy.add(key);
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .patchSettings({key: newValue});
      ref.invalidate(notificationSettingsProvider);
      if (!mounted) return;
      _maybeShowSuccessSnack(messenger);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (previousServerValue != null) {
          _optimistic[key] = previousServerValue;
        } else {
          _optimistic.remove(key);
        }
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (previousServerValue != null) {
          _optimistic[key] = previousServerValue;
        } else {
          _optimistic.remove(key);
        }
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('تعذّر حفظ الإعدادات'),
        ));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Reads the current server-truth value for a key. Used to remember
  /// what to revert to on failure. Returns `null` if the key is unknown.
  bool? _readServerValue(String key) {
    final snap = ref.read(notificationSettingsProvider).valueOrNull;
    if (snap == null) return null;
    if (key == 'notifications_enabled') {
      return snap.notificationsMasterEnabled;
    }
    if (key == 'telegram_enabled') return snap.telegram.enabled;
    if (key == 'sms_enabled') return snap.sms.enabled;
    for (final s in snap.sectionSwitches) {
      if (s.enabledKey == key) return s.enabled;
    }
    return null;
  }

  /// Show a calm "تم حفظ إعدادات الإشعارات" snackbar at most once every
  /// ~1.5 s, so a rapid flurry of toggles doesn't stack confirmations.
  void _maybeShowSuccessSnack(ScaffoldMessengerState messenger) {
    final now = DateTime.now();
    if (now.difference(_lastSuccessSnack).inMilliseconds < 1500) return;
    _lastSuccessSnack = now;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('تم حفظ إعدادات الإشعارات'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('إعدادات الإشعارات'),
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(notificationSettingsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(notificationSettingsProvider),
          child: settings.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل الإعدادات...'),
              ],
            ),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AppErrorState(
                  error: err is ApiException
                      ? err
                      : ApiException(
                          message: 'تعذّر تحميل الإعدادات.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () =>
                      ref.invalidate(notificationSettingsProvider),
                ),
              ],
            ),
            data: (s) {
              // Drop overrides whose server-side truth has caught up.
              _reconcile(s);
              return _Body(
                snapshot: s,
                optimistic: _optimistic,
                busy: _busy,
                onPatch: _patchOne,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snapshot,
    required this.optimistic,
    required this.busy,
    required this.onPatch,
  });

  final NotificationSettingsSnapshot snapshot;
  final Map<String, bool> optimistic;
  final Set<String> busy;
  final void Function(String key, bool value) onPatch;

  bool _value(String key, bool serverValue) =>
      optimistic[key] ?? serverValue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _ScopeBanner(scope: snapshot.scope),
        const SizedBox(height: 12),
        _MasterCard(
          enabled: _value(
              'notifications_enabled', snapshot.notificationsMasterEnabled),
          busy: busy.contains('notifications_enabled'),
          onChanged: (v) => onPatch('notifications_enabled', v),
        ),
        const SizedBox(height: 12),
        _ChannelsCard(
          telegram: snapshot.telegram,
          sms: snapshot.sms,
          telegramEffective:
              _value('telegram_enabled', snapshot.telegram.enabled),
          smsEffective: _value('sms_enabled', snapshot.sms.enabled),
          busy: busy,
          onPatch: onPatch,
        ),
        if (snapshot.sectionSwitches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionsCard(
            switches: snapshot.sectionSwitches,
            effective: (s) => _value(s.enabledKey, s.enabled),
            busy: busy,
            onPatch: onPatch,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context) {
    final isGlobal = scope == 'global' || scope.isEmpty;
    final text = isGlobal
        ? 'هذه الإعدادات عامة لحسابك وليست لكل جهاز على حدة.'
        : 'نطاق الإعدادات: $scope';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.indigoBright.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.indigoPrimary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppTheme.indigoPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفعيل الإشعارات',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'مفتاح رئيسي يوقف كل قنوات الإشعارات عند إغلاقه.',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          _SwitchOrSpinner(
            value: enabled,
            busy: busy,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard({
    required this.telegram,
    required this.sms,
    required this.telegramEffective,
    required this.smsEffective,
    required this.busy,
    required this.onPatch,
  });

  final NotificationChannelStatus telegram;
  final NotificationChannelStatus sms;
  final bool telegramEffective;
  final bool smsEffective;
  final Set<String> busy;
  final void Function(String key, bool value) onPatch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قنوات الإشعار',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ChannelRow(
            label: 'تيليجرام',
            settingKey: 'telegram_enabled',
            channel: telegram,
            value: telegramEffective,
            busy: busy.contains('telegram_enabled'),
            onChanged: (v) => onPatch('telegram_enabled', v),
          ),
          const SizedBox(height: 8),
          _ChannelRow(
            label: 'الرسائل القصيرة SMS',
            settingKey: 'sms_enabled',
            channel: sms,
            value: smsEffective,
            busy: busy.contains('sms_enabled'),
            onChanged: (v) => onPatch('sms_enabled', v),
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.label,
    required this.settingKey,
    required this.channel,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  // ignore: unused_element_parameter
  final String settingKey;
  final NotificationChannelStatus channel;

  /// v90c: effective (optimistic) value to render. Falls back to the
  /// server value at the parent level when no override is present.
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final configuredColor = channel.configured
        ? AppTheme.success
        : AppTheme.faintMuted;
    final configuredLabel =
        channel.configured ? 'مهيأة' : 'غير مهيأة';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: configuredColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: configuredColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  configuredLabel,
                  style: TextStyle(
                    color: configuredColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        _SwitchOrSpinner(
          value: value,
          busy: busy,
          onChanged: channel.configured ? onChanged : null,
        ),
      ],
    );
  }
}

class _SectionsCard extends StatelessWidget {
  const _SectionsCard({
    required this.switches,
    required this.effective,
    required this.busy,
    required this.onPatch,
  });

  final List<NotificationSectionSwitch> switches;

  /// v90c: parent-supplied resolver that returns the effective (possibly
  /// optimistic) value for a given section switch.
  final bool Function(NotificationSectionSwitch s) effective;
  final Set<String> busy;
  final void Function(String key, bool value) onPatch;

  static const Map<String, String> _sectionLabels = {
    'periodic_day': 'تقارير دورية - النهار',
    'periodic_night': 'تقارير دورية - الليل',
    'sunset': 'قبل الغروب',
    'discharge': 'تفريغ البطارية ليلاً',
    'load': 'تنبيهات الأحمال',
    'weather': 'تنبيهات الطقس',
    'battery': 'تنبيهات البطارية',
    'daily_report': 'التقرير اليومي',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فئات الإشعارات',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in switches) ...[
            _SectionRow(
              label: _sectionLabels[s.sectionId] ?? s.sectionId,
              value: effective(s),
              busy: busy.contains(s.enabledKey),
              onChanged: (v) => onPatch(s.enabledKey, v),
            ),
            if (s != switches.last)
              const Divider(
                color: AppTheme.line,
                height: 12,
                thickness: 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.label,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SwitchOrSpinner(
            value: value,
            busy: busy,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// v90c: switch with an inline "جارٍ الحفظ" pill while a PATCH is in
/// flight. The switch itself stays visible and reflects the optimistic
/// value passed in, mirroring the v90b loads pattern. `onChanged: null`
/// while busy prevents a double-tap on the same row.
class _SwitchOrSpinner extends StatelessWidget {
  const _SwitchOrSpinner({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Switch(
          value: value,
          activeThumbColor: AppTheme.indigoPrimary,
          onChanged: busy ? null : onChanged,
        ),
        if (busy)
          Positioned(
            bottom: -2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.indigoSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'جارٍ الحفظ',
                style: TextStyle(
                  color: AppTheme.indigoPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
