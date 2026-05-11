import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/device_detail_models.dart';
import '../data/device_detail_repository.dart';
import '../state/selected_device_provider.dart';

/// Read-only Device Details (v47).
///
/// Pulls `GET /api/mobile/devices/:id` and renders three calm cards:
/// header (name + status), latest reading summary (server-computed `cards`
/// values), and metadata (timezone, timestamps, safe settings). The only
/// state-changing action is "set as active device", which writes the
/// id into the local [selectedDeviceProvider] — no backend mutation.
class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v57: hard-guard for an invalid path parameter. If the router ever
    // produces id == 0 (parse failure, empty path segment, etc.), render an
    // honest error instead of firing a doomed `/devices/0` fetch.
    if (deviceId <= 0) {
      return Scaffold(
        backgroundColor: AppTheme.softBg,
        appBar: AppBar(title: const Text('تفاصيل الجهاز')),
        body: SafeArea(
          child: AppErrorState(
            error: ApiException(
              message: 'معرّف الجهاز غير صالح.',
              kind: ApiErrorKind.notFound,
            ),
          ),
        ),
      );
    }

    final detail = ref.watch(deviceDetailProvider(deviceId));
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('تفاصيل الجهاز'),
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(deviceDetailProvider(deviceId)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(deviceDetailProvider(deviceId)),
          // v57: wrap every detail-state branch in a ListView so
          // RefreshIndicator always has a scrollable child to drive (and so
          // pull-to-refresh works even while loading / on error). This also
          // makes the body always visible — no more silent blank state.
          child: detail.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل تفاصيل الجهاز...'),
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
                          message: 'تعذّر تحميل تفاصيل الجهاز.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () =>
                      ref.invalidate(deviceDetailProvider(deviceId)),
                ),
              ],
            ),
            data: (snapshot) {
              // v57: if the server returned an empty/zero device payload,
              // surface that as a calm empty state — never as a blank body.
              if (snapshot.device.id == 0) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppErrorState(
                      error: ApiException(
                        message: 'تعذّر العثور على بيانات هذا الجهاز.',
                        kind: ApiErrorKind.notFound,
                      ),
                      onRetry: () =>
                          ref.invalidate(deviceDetailProvider(deviceId)),
                    ),
                  ],
                );
              }
              return _DetailBody(
                snapshot: snapshot,
                isActive: activeId == snapshot.device.id,
                onSetActive: () => ref
                    .read(selectedDeviceProvider.notifier)
                    .select(snapshot.device.id),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.snapshot,
    required this.isActive,
    required this.onSetActive,
  });

  final DeviceDetailSnapshot snapshot;
  final bool isActive;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    final d = snapshot.device;
    final l = snapshot.latest;
    // v52: section order matches the polished IA — status first (most
    // glanceable), then latest reading, safe settings (if any), device
    // info (with history merged in), then the only action.
    final children = <Widget>[
      _StatusCard(device: d, isActive: isActive),
      const SizedBox(height: 12),
      _LatestCard(latest: l),
      if (d.safeSettings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SettingsCard(settings: d.safeSettings),
      ],
      const SizedBox(height: 12),
      _InfoCard(device: d),
      const SizedBox(height: 16),
      _ActionRow(isActive: isActive, onSetActive: onSetActive),
      const SizedBox(height: 24),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.device, required this.isActive});
  final DeviceDetail device;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final connected = device.connectionStatus.toLowerCase() == 'ok';
    final lastSeen = _formatTimestamp(device.lastConnectedAt);
    return AppCard(
      borderColor: isActive ? AppTheme.indigoBright : AppTheme.line,
      background: isActive ? AppTheme.indigoSoft : AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الحالة'),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.surface : AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.solar_power_outlined,
                  color: AppTheme.indigoPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isNotEmpty ? device.name : '#${device.id}',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (device.plantName.isNotEmpty &&
                        device.plantName != device.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        device.plantName,
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: connected
                    ? 'متصل'
                    : (device.connectionStatus.isNotEmpty
                        ? device.connectionStatus
                        : 'غير متصل'),
                color: connected ? AppTheme.success : AppTheme.faintMuted,
              ),
              if (isActive)
                const _StatusChip(
                  label: 'الجهاز النشط',
                  color: AppTheme.indigoPrimary,
                  filled: true,
                ),
            ],
          ),
          if (lastSeen != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    color: AppTheme.faintMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  'آخر اتصال: $lastSeen',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.latest});
  final DeviceLatestSummary latest;

  @override
  Widget build(BuildContext context) {
    if (!latest.hasReading) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SectionTitle(label: 'آخر قراءة'),
            SizedBox(height: 8),
            Text(
              'لا توجد قراءات بعد لهذا الجهاز.',
              style: TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    }

    // v52: 2-column tile grid for the five readings. Each tile carries an
    // icon, an Arabic label, and the value with its unit, so the readings
    // are glanceable instead of buried in flat key-value rows.
    final tiles = <_StatTile>[
      _StatTile(
        icon: Icons.wb_sunny_outlined,
        tone: AppTheme.warning,
        label: 'الإنتاج الشمسي',
        value: '${_fmt(latest.solarPowerW)} W',
      ),
      _StatTile(
        icon: Icons.home_outlined,
        tone: AppTheme.indigoPrimary,
        label: 'استهلاك المنزل',
        value: '${_fmt(latest.homeLoadW)} W',
      ),
      _StatTile(
        icon: Icons.battery_charging_full_outlined,
        tone: AppTheme.success,
        label: 'شحن البطارية',
        value: '${_fmt(latest.batterySocPercent)}%',
      ),
      _StatTile(
        icon: Icons.battery_std_outlined,
        tone: AppTheme.success,
        label: 'طاقة البطارية',
        value: '${_fmt(latest.batteryPowerW)} W',
      ),
      _StatTile(
        icon: Icons.bolt_outlined,
        tone: AppTheme.violet,
        label: 'تبادل الشبكة',
        value: '${_fmt(latest.gridPowerW)} W',
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      // v57: wrap each tile-row in IntrinsicHeight so
      // `CrossAxisAlignment.stretch` can resolve a bounded cross-axis
      // height. Without this, the surrounding ListView passes unbounded
      // vertical constraints down to the Row and RenderFlex bails out
      // mid-layout — in release that surfaces as a blank screen body
      // under the AppBar (root cause of the v57 manual-QA report).
      rows.add(Padding(
        padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 8),
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'آخر قراءة'),
          const SizedBox(height: 10),
          ...rows,
          if (latest.createdAt != null && latest.createdAt!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    color: AppTheme.faintMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  'تحديث: ${_formatTimestamp(latest.createdAt) ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (latest.statusText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              latest.statusText,
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.settings});
  final Map<String, String> settings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الإعدادات الآمنة'),
          const SizedBox(height: 8),
          for (final entry in settings.entries)
            _KvRow(
              label: _settingLabel(entry.key),
              value: _settingValue(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  static String _settingLabel(String key) {
    switch (key) {
      case 'battery_capacity_kwh':
        return 'سعة البطارية';
      case 'battery_reserve_percent':
        return 'احتياطي البطارية';
      default:
        return key;
    }
  }

  static String _settingValue(String key, String raw) {
    switch (key) {
      case 'battery_capacity_kwh':
        return '$raw kWh';
      case 'battery_reserve_percent':
        return '$raw%';
      default:
        return raw;
    }
  }
}

/// v52: combined device info — type/provider/timezone/id + the history
/// rows (created/updated/last_connected). Replaces the prior split
/// _ProviderCard + _MetaCard so the user sees one cohesive "info" block.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.device});
  final DeviceDetail device;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'معلومات الجهاز'),
          const SizedBox(height: 8),
          _KvRow(
            label: 'النوع',
            value: device.deviceType.isNotEmpty
                ? device.deviceType.toUpperCase()
                : '—',
          ),
          _KvRow(
            label: 'المزوّد',
            value: device.apiProvider.isNotEmpty
                ? device.apiProvider.toUpperCase()
                : '—',
          ),
          _KvRow(
            label: 'المنطقة الزمنية',
            value: device.timezone.isNotEmpty ? device.timezone : '—',
          ),
          _KvRow(label: 'المعرّف', value: '#${device.id}'),
          const Divider(color: AppTheme.line, height: 18, thickness: 1),
          _KvRow(
            label: 'آخر اتصال',
            value: _formatTimestamp(device.lastConnectedAt) ?? '—',
          ),
          _KvRow(
            label: 'تاريخ الإنشاء',
            value: _formatTimestamp(device.createdAt) ?? '—',
          ),
          _KvRow(
            label: 'آخر تحديث',
            value: _formatTimestamp(device.updatedAt) ?? '—',
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.isActive, required this.onSetActive});
  final bool isActive;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.indigoSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.indigoBright.withValues(alpha: 0.40)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppTheme.indigoPrimary, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'هذا هو جهازك النشط الحالي.',
                style: TextStyle(
                  color: AppTheme.indigoPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: AppTheme.formControlHeight + 4,
      child: FilledButton.icon(
        onPressed: onSetActive,
        icon: const Icon(Icons.bolt_outlined, size: 18),
        label: const Text('تعيين كجهاز نشط'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : color.withValues(alpha: 0.10);
    final fg = filled ? Colors.white : color;
    final border =
        filled ? color : color.withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _fmt(double v) {
  if (v == 0) return '0';
  final abs = v.abs();
  if (abs >= 100) return v.toStringAsFixed(0);
  if (abs >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

/// Compact local-time formatter for ISO-8601 strings coming from the
/// backend. Falls back to the raw string when parsing fails so the user
/// still sees what the server sent.
String? _formatTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d  $hh:$mm';
}
