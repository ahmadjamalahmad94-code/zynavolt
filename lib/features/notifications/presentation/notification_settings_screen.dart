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
  /// Tracks which key is currently being PATCHed so the row can show a
  /// spinner instead of a switch.
  String? _busyKey;

  Future<void> _patchOne(String key, bool value) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .patchSettings({key: value});
      ref.invalidate(notificationSettingsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text('تعذّر تحديث الإعدادات: $e')));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
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
            data: (s) => _Body(
              snapshot: s,
              busyKey: _busyKey,
              onPatch: _patchOne,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.snapshot,
    required this.busyKey,
    required this.onPatch,
  });

  final NotificationSettingsSnapshot snapshot;
  final String? busyKey;
  final void Function(String key, bool value) onPatch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _ScopeBanner(scope: snapshot.scope),
        const SizedBox(height: 12),
        _MasterCard(
          enabled: snapshot.notificationsMasterEnabled,
          busy: busyKey == 'notifications_enabled',
          onChanged: (v) => onPatch('notifications_enabled', v),
        ),
        const SizedBox(height: 12),
        _ChannelsCard(
          telegram: snapshot.telegram,
          sms: snapshot.sms,
          busyKey: busyKey,
          onPatch: onPatch,
        ),
        if (snapshot.sectionSwitches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionsCard(
            switches: snapshot.sectionSwitches,
            busyKey: busyKey,
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
    required this.busyKey,
    required this.onPatch,
  });

  final NotificationChannelStatus telegram;
  final NotificationChannelStatus sms;
  final String? busyKey;
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
            busy: busyKey == 'telegram_enabled',
            onChanged: (v) => onPatch('telegram_enabled', v),
          ),
          const SizedBox(height: 8),
          _ChannelRow(
            label: 'الرسائل القصيرة SMS',
            settingKey: 'sms_enabled',
            channel: sms,
            busy: busyKey == 'sms_enabled',
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
    required this.busy,
    required this.onChanged,
  });

  final String label;
  // ignore: unused_element_parameter
  final String settingKey;
  final NotificationChannelStatus channel;
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
          value: channel.enabled,
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
    required this.busyKey,
    required this.onPatch,
  });

  final List<NotificationSectionSwitch> switches;
  final String? busyKey;
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
              value: s.enabled,
              busy: busyKey == s.enabledKey,
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
    if (busy) {
      return const SizedBox(
        width: 36,
        height: 24,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }
    return Switch(
      value: value,
      activeThumbColor: AppTheme.indigoPrimary,
      onChanged: onChanged,
    );
  }
}
