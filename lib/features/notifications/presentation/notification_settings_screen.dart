import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/notification_settings_models.dart';
import '../data/notifications_repository.dart';

/// v102 DS v1 — إعدادات الإشعارات.
///
/// Focused subset of `GET /api/mobile/notifications/settings`:
/// master switch, telegram/SMS/Push channels + per-section
/// toggles. Each change PATCHes the backend; per-key optimistic
/// override keeps the UI responsive while the request is in
/// flight. Provider credentials never appear in the UI.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, bool> _optimistic = {};
  final Set<String> _busy = {};
  DateTime _lastSuccessSnack = DateTime.fromMillisecondsSinceEpoch(0);

  void _reconcile(NotificationSettingsSnapshot fresh) {
    if (_optimistic.isEmpty) return;
    final next = <String, bool>{};
    bool serverMatchesOverride(String key, bool override) {
      if (key == 'notifications_enabled') {
        return fresh.notificationsMasterEnabled == override;
      }
      if (key == 'telegram_enabled') return fresh.telegram.enabled == override;
      if (key == 'sms_enabled') return fresh.sms.enabled == override;
      if (key == 'push_enabled') return fresh.push.enabled == override;
      for (final s in fresh.sectionSwitches) {
        if (s.enabledKey == key) return s.enabled == override;
      }
      return false;
    }

    _optimistic.forEach((key, value) {
      if (!serverMatchesOverride(key, value)) {
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

  bool? _readServerValue(String key) {
    final snap = ref.read(notificationSettingsProvider).valueOrNull;
    if (snap == null) return null;
    if (key == 'notifications_enabled') {
      return snap.notificationsMasterEnabled;
    }
    if (key == 'telegram_enabled') return snap.telegram.enabled;
    if (key == 'sms_enabled') return snap.sms.enabled;
    if (key == 'push_enabled') return snap.push.enabled;
    for (final s in snap.sectionSwitches) {
      if (s.enabledKey == key) return s.enabled;
    }
    return null;
  }

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

    return ZynScreen(
      hero: ZynPageHero(
        title: 'إعدادات الإشعارات',
        subtitle: 'قنوات الإشعار وفئاتها للتنبيهات الفورية.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(notificationSettingsProvider),
        ),
      ),
      child: settings.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل الإعدادات...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل الإعدادات.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (s) {
          _reconcile(s);
          return _Body(
            snapshot: s,
            optimistic: _optimistic,
            busy: _busy,
            onPatch: _patchOne,
          );
        },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScopeBanner(scope: snapshot.scope),
        const SizedBox(height: ZynSpacing.md),
        _MasterCard(
          enabled: _value(
            'notifications_enabled',
            snapshot.notificationsMasterEnabled,
          ),
          busy: busy.contains('notifications_enabled'),
          onChanged: (v) => onPatch('notifications_enabled', v),
        ),
        const SizedBox(height: ZynSpacing.md),
        _ChannelsCard(
          telegram: snapshot.telegram,
          sms: snapshot.sms,
          push: snapshot.push,
          telegramEffective:
              _value('telegram_enabled', snapshot.telegram.enabled),
          smsEffective: _value('sms_enabled', snapshot.sms.enabled),
          pushEffective: _value('push_enabled', snapshot.push.enabled),
          busy: busy,
          onPatch: onPatch,
        ),
        if (snapshot.sectionSwitches.isNotEmpty) ...[
          const SizedBox(height: ZynSpacing.md),
          _SectionsCard(
            switches: snapshot.sectionSwitches,
            effective: (s) => _value(s.enabledKey, s.enabled),
            busy: busy,
            onPatch: onPatch,
          ),
        ],
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
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: ZynColors.primary700, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ZynColors.primary700,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: ZynGradients.glossSurface(tint: ZynColors.primary500),
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.med(),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZynGradients.iconFill(ZynColors.primary500),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفعيل الإشعارات',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'مفتاح رئيسي يوقف كل قنوات الإشعارات عند إغلاقه.',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _SwitchOrSpinner(value: enabled, busy: busy, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard({
    required this.telegram,
    required this.sms,
    required this.push,
    required this.telegramEffective,
    required this.smsEffective,
    required this.pushEffective,
    required this.busy,
    required this.onPatch,
  });

  final NotificationChannelStatus telegram;
  final NotificationChannelStatus sms;
  final NotificationChannelStatus push;
  final bool telegramEffective;
  final bool smsEffective;
  final bool pushEffective;
  final Set<String> busy;
  final void Function(String key, bool value) onPatch;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قنوات الإشعار',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _ChannelRow(
            label: 'تيليجرام',
            channel: telegram,
            value: telegramEffective,
            busy: busy.contains('telegram_enabled'),
            onChanged: (v) => onPatch('telegram_enabled', v),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _ChannelRow(
            label: 'الرسائل القصيرة SMS',
            channel: sms,
            value: smsEffective,
            busy: busy.contains('sms_enabled'),
            onChanged: (v) => onPatch('sms_enabled', v),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _ChannelRow(
            label: 'الإشعارات الفورية (Push)',
            channel: push,
            value: pushEffective,
            busy: busy.contains('push_enabled'),
            onChanged: (v) => onPatch('push_enabled', v),
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.label,
    required this.channel,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final String label;
  final NotificationChannelStatus channel;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final configuredColor =
        channel.configured ? ZynColors.success : ZynColors.muted;
    final configuredLabel = channel.configured ? 'مهيأة' : 'غير مهيأة';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ZynColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: configuredColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ZynRadii.pill),
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فئات الإشعارات',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          for (final s in switches) ...[
            _SectionRow(
              label: _sectionLabels[s.sectionId] ?? s.sectionId,
              value: effective(s),
              busy: busy.contains(s.enabledKey),
              onChanged: (v) => onPatch(s.enabledKey, v),
            ),
            if (s != switches.last)
              const Divider(
                color: ZynColors.lineSoft,
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
                color: ZynColors.ink,
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
          activeThumbColor: ZynColors.primary500,
          onChanged: busy ? null : onChanged,
        ),
        if (busy)
          Positioned(
            bottom: -2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ZynColors.primary50,
                borderRadius: BorderRadius.circular(ZynRadii.pill),
              ),
              child: const Text(
                'جارٍ الحفظ',
                style: TextStyle(
                  color: ZynColors.primary700,
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: child,
    );
  }
}
