import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/utils/backend_time.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/device_detail_models.dart';
import '../data/device_detail_repository.dart';
import '../data/device_diagnostics_models.dart';
import '../data/device_diagnostics_repository.dart';
import '../data/devices_repository.dart';
import '../state/selected_device_provider.dart';
import 'device_setup_screen.dart';
import 'edit_device_screen.dart';

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
      return ZynScreen(
        hero: const ZynPageHero(
          title: 'تفاصيل الجهاز',
          subtitle: 'حالة الجهاز وقراءاته الأخيرة.',
        ),
        child: AppErrorState(
          error: ApiException(
            message: 'معرّف الجهاز غير صالح.',
            kind: ApiErrorKind.notFound,
          ),
        ),
      );
    }

    final detail = ref.watch(deviceDetailProvider(deviceId));
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return ZynScreen(
      hero: ZynPageHero(
        title: 'تفاصيل الجهاز',
        subtitle: 'حالة الجهاز، آخر قراءة، والإعدادات الآمنة.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: () {
            ref.invalidate(deviceDetailProvider(deviceId));
            ref.invalidate(deviceHistoryProvider(deviceId));
            ref.invalidate(deviceAlertsProvider(deviceId));
          },
        ),
      ),
      child: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل تفاصيل الجهاز...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل تفاصيل الجهاز.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: () => ref.invalidate(deviceDetailProvider(deviceId)),
        ),
        data: (snapshot) {
          if (snapshot.device.id == 0) {
            return AppErrorState(
              error: ApiException(
                message: 'تعذّر العثور على بيانات هذا الجهاز.',
                kind: ApiErrorKind.notFound,
              ),
              onRetry: () => ref.invalidate(deviceDetailProvider(deviceId)),
            );
          }
          return _DetailBody(
            snapshot: snapshot,
            isActive: activeId == snapshot.device.id,
            onSetActive: () => ref
                .read(selectedDeviceProvider.notifier)
                .select(snapshot.device.id),
            onOpenSetup: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      DeviceSetupScreen(device: snapshot.device),
                ),
              );
              if (saved == true) {
                ref.invalidate(deviceDetailProvider(deviceId));
              }
            },
            onChanged: () => ref.invalidate(deviceDetailProvider(deviceId)),
            onDeleted: () {
              ref.invalidate(devicesListProvider);
              ref.invalidate(deviceDetailProvider(deviceId));
              Navigator.of(context).maybePop();
            },
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.snapshot,
    required this.isActive,
    required this.onSetActive,
    required this.onOpenSetup,
    required this.onChanged,
    required this.onDeleted,
  });

  final DeviceDetailSnapshot snapshot;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onOpenSetup;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final d = snapshot.device;
    final l = snapshot.latest;
    final needsSetup =
        d.connectionStatus.trim().toLowerCase() == 'setup_required';
    // v52: section order matches the polished IA — status first (most
    // glanceable), then latest reading, safe settings (if any), device
    // info (with history merged in), then the only action.
    // v49: setup CTA injected right after the status hero when the
    // device hasn't received its credentials yet.
    final children = <Widget>[
      _StatusCard(
        device: d,
        isActive: isActive,
        onChanged: onChanged,
        onDeleted: onDeleted,
      ),
      if (needsSetup) ...[
        const SizedBox(height: 12),
        _SetupRequiredCard(onTap: onOpenSetup),
      ],
      // v52: server-derived alerts card. Renders ONLY when the backend
      // currently has alerts to show — the card otherwise occupies
      // zero height so users in a healthy steady state don't see an
      // empty "no alerts" panel.
      _AlertsCard(deviceId: d.id),
      const SizedBox(height: 12),
      // v46: compact integration-health summary card. Every row is
      // sourced from an existing backend payload field — no inference,
      // no client-side health scoring. Cards renders the same data the
      // upstream cards already expose, just consolidated and translated.
      _IntegrationHealthCard(device: d, latest: l),
      // v50: subscriber-facing "sync now" action. Hidden when the
      // device isn't active — the backend would reject the call with
      // `device_inactive` anyway. Otherwise always available so the
      // user can verify connectivity without waiting for the next
      // auto-sync tick (default 5 min).
      if (d.isActive) ...[
        const SizedBox(height: 12),
        _SyncNowButton(deviceId: d.id),
      ],
      const SizedBox(height: 12),
      _LatestCard(latest: l),
      if (d.safeSettings.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SettingsCard(settings: d.safeSettings),
      ],
      const SizedBox(height: 12),
      _InfoCard(device: d),
      // v52: historical readings list. Secondary, placed after the
      // primary info card per the brief's "clearly secondary"
      // requirement. Renders a compact top-N list with loading /
      // empty / error states.
      const SizedBox(height: 12),
      _HistoryCard(deviceId: d.id),
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
  const _StatusCard({
    required this.device,
    required this.isActive,
    required this.onChanged,
    required this.onDeleted,
  });
  final DeviceDetail device;
  final bool isActive;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final connected = device.connectionStatus.toLowerCase() == 'ok';
    final lastSeen = formatDateTime(device.lastConnectedAt);
    return AppCard(
      elevated: true,
      borderColor: isActive ? ZynColors.primary500 : ZynColors.line,
      background: isActive ? ZynColors.primary50 : ZynColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionTitle(label: 'الحالة')),
              _DeviceDetailMenu(
                device: device,
                onChanged: onChanged,
                onDeleted: onDeleted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? ZynColors.surface : ZynColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.solar_power_outlined,
                  color: ZynColors.primary700,
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
                        color: ZynColors.ink,
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
                          color: ZynColors.muted,
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
                color: connected ? ZynColors.success : ZynColors.muted,
              ),
              if (isActive)
                const _StatusChip(
                  label: 'الجهاز النشط',
                  color: ZynColors.primary700,
                  filled: true,
                ),
            ],
          ),
          if (lastSeen != null) ...[
            const SizedBox(height: 12),
            // v63: small chip with icon container so "آخر اتصال" reads
            // as a deliberate metadata cell, not stray footer text.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ZynColors.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: ZynColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_outlined,
                      color: ZynColors.muted, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    'آخر اتصال: $lastSeen',
                    style: const TextStyle(
                      color: ZynColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// v46: compact "حالة التكامل" card — honest, backend-sourced rows
/// only. Reads four signals straight from the existing device-detail
/// payload (no extra fetches, no client-side computation of state):
///   * `device.connection_status` → connection chip (translated to
///     Arabic for the three known values: `new` / `ok` /
///     `setup_required`).
///   * `latest.created_at` → data-freshness chip + Arabic relative-time
///     label. The freshness threshold is purely a presentation cue;
///     the underlying value is the raw timestamp the backend already
///     surfaces in [_LatestCard].
///   * `latest.status_text` → optional backend-origin Arabic status
///     line (rendered only when non-empty).
///
/// Intentionally absent (the API does not expose these fields):
///   * weather availability
///   * notifications-enabled flag
///   * sync interval / next sync ETA
/// v49: high-visibility CTA card surfaced only when the device's
/// `connection_status == 'setup_required'`. Tapping it opens the
/// dynamic provider-setup form. Tonal — uses the warning palette to
/// make it obvious without being alarming, since "setup pending" is
/// not a fault state.
class _SetupRequiredCard extends StatelessWidget {
  const _SetupRequiredCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: AppCard(
          background: ZynColors.warning.withValues(alpha: 0.06),
          borderColor: ZynColors.warning.withValues(alpha: 0.30),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.settings_input_component_outlined,
                  color: ZynColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إكمال إعداد المزوّد',
                      style: TextStyle(
                        color: ZynColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'هذا الجهاز يحتاج إلى بيانات الاتصال بالمزوّد. '
                      'اضغط للمتابعة وإدخالها.',
                      style: TextStyle(
                        color: ZynColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left,
                  color: ZynColors.muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegrationHealthCard extends StatelessWidget {
  const _IntegrationHealthCard({required this.device, required this.latest});

  final DeviceDetail device;
  final DeviceLatestSummary latest;

  @override
  Widget build(BuildContext context) {
    final connection = _connectionDisplay(device.connectionStatus);
    final freshness = _freshnessDisplay(latest.createdAt);
    final backendStatus = latest.statusText.trim();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'حالة التكامل'),
          const SizedBox(height: 10),
          _HealthRow(
            icon: Icons.link_outlined,
            label: 'الاتصال',
            value: connection.label,
            tone: connection.tone,
          ),
          const SizedBox(height: 8),
          _HealthRow(
            icon: Icons.schedule_outlined,
            label: 'حداثة البيانات',
            value: freshness.label,
            tone: freshness.tone,
          ),
          if (backendStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            _HealthRow(
              icon: Icons.info_outline,
              label: 'حالة النظام',
              value: backendStatus,
              tone: ZynColors.primary700,
            ),
          ],
        ],
      ),
    );
  }
}

/// One row inside [_IntegrationHealthCard]. Visually compact, RTL-clean:
/// label on the leading side in muted Arabic, value on the trailing side
/// in a soft pill that picks up the row's tone colour. The pill is tonal
/// only — never used to imply "good"/"bad" without backend evidence.
class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: tone),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tone.withValues(alpha: 0.30)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Resolved presentation tuple for the connection row.
class _StatusDisplay {
  const _StatusDisplay(this.label, this.tone);
  final String label;
  final Color tone;
}

/// Translate the backend's `connection_status` slug (`new` / `ok` /
/// `setup_required` per `app/models.py`) into an Arabic label + tone.
/// Unknown values render verbatim so the user still sees the raw
/// signal — no fake "متصل" success label for an unrecognised state.
_StatusDisplay _connectionDisplay(String raw) {
  final norm = raw.trim().toLowerCase();
  switch (norm) {
    case 'ok':
      return const _StatusDisplay('متصل', ZynColors.success);
    case 'new':
      return const _StatusDisplay('جديد', ZynColors.primary700);
    case 'setup_required':
      return const _StatusDisplay('بحاجة إلى إعداد', ZynColors.warning);
    case '':
      return const _StatusDisplay('غير معروف', ZynColors.muted);
    default:
      // Fall back to the raw value so we never hide a real backend
      // signal behind a localisation gap.
      return _StatusDisplay(raw, ZynColors.muted);
  }
}

/// Resolve the freshness row from the latest reading's timestamp.
/// The thresholds are presentation cues only — the underlying value
/// is the same backend ISO already shown in [_LatestCard].
_StatusDisplay _freshnessDisplay(String? iso) {
  final parsed = parseBackendIso(iso);
  if (parsed == null) {
    return const _StatusDisplay('لا توجد قراءات', ZynColors.muted);
  }
  final ageMinutes =
      DateTime.now().difference(parsed.toLocal()).inMinutes;
  // Negative ages (clock skew) are still "now" for presentation.
  final safeMinutes = ageMinutes < 0 ? 0 : ageMinutes;
  final relative = _arabicRelativeAge(safeMinutes);
  if (safeMinutes <= 15) {
    return _StatusDisplay('حديثة · $relative', ZynColors.success);
  }
  if (safeMinutes <= 60) {
    return _StatusDisplay('ضمن الساعة · $relative', ZynColors.primary700);
  }
  return _StatusDisplay('قديمة · $relative', ZynColors.warning);
}

/// Calm Arabic "since N minutes/hours/days ago" formatter. Uses
/// Western digits to stay consistent with the rest of the app.
/// Plural-form fidelity is intentionally simple: the brief asks for
/// calm wording, not strict Arabic dual/plural grammar.
String _arabicRelativeAge(int minutes) {
  if (minutes < 1) return 'منذ لحظات';
  if (minutes < 60) return 'منذ $minutes دقيقة';
  final hours = minutes ~/ 60;
  if (hours < 24) return 'منذ $hours ساعة';
  final days = hours ~/ 24;
  return 'منذ $days يوم';
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
                color: ZynColors.muted,
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
        tone: ZynColors.warning,
        label: 'الإنتاج الشمسي',
        value: '${_fmt(latest.solarPowerW)} W',
      ),
      _StatTile(
        icon: Icons.home_outlined,
        tone: ZynColors.primary700,
        label: 'استهلاك المنزل',
        value: '${_fmt(latest.homeLoadW)} W',
      ),
      _StatTile(
        icon: Icons.battery_charging_full_outlined,
        tone: ZynColors.success,
        label: 'شحن البطارية',
        value: '${_fmt(latest.batterySocPercent)}%',
      ),
      _StatTile(
        icon: Icons.battery_std_outlined,
        tone: ZynColors.success,
        label: 'طاقة البطارية',
        value: '${_fmt(latest.batteryPowerW)} W',
      ),
      _StatTile(
        icon: Icons.bolt_outlined,
        tone: ZynColors.accent,
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
                    color: ZynColors.muted, size: 14),
                const SizedBox(width: 6),
                Text(
                  'تحديث: ${formatDateTime(latest.createdAt) ?? ''}',
                  style: const TextStyle(
                    color: ZynColors.muted,
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
                color: ZynColors.muted,
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
        color: ZynColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZynColors.line),
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
                    color: ZynColors.muted,
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
                color: ZynColors.ink,
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
          // v45: small compact Arabic label for the provider readiness
          // tier. The backend resolves both the structured value and
          // the Arabic label, so the mobile only needs to render —
          // never to map codes. Hidden entirely when the field is
          // absent (older backend or unknown provider code).
          if ((device.providerSupportTierLabel ?? '').isNotEmpty)
            _KvRow(
              label: 'حالة الدعم',
              value: device.providerSupportTierLabel!,
            ),
          _KvRow(
            label: 'المنطقة الزمنية',
            value: device.timezone.isNotEmpty ? device.timezone : '—',
          ),
          _KvRow(label: 'المعرّف', value: '#${device.id}'),
          const Divider(color: ZynColors.line, height: 18, thickness: 1),
          _KvRow(
            label: 'آخر اتصال',
            value: formatDateTime(device.lastConnectedAt) ?? '—',
          ),
          _KvRow(
            label: 'تاريخ الإنشاء',
            value: formatDateTime(device.createdAt) ?? '—',
          ),
          _KvRow(
            label: 'آخر تحديث',
            value: formatDateTime(device.updatedAt) ?? '—',
          ),
        ],
      ),
    );
  }
}

/// v51: AppBar overflow menu with two subscriber-facing actions:
///   * "تعديل" — opens [EditDeviceScreen] with the live device
///     snapshot, invalidates `deviceDetailProvider` on save success.
///   * "حذف الجهاز" — shows an honest confirmation dialog. The
///     backend's `DELETE /api/mobile/devices/<id>` actually performs
///     a deactivation (sets `is_active=False`, returns
///     `{deleted:false, deactivated:true}`), so the UI never claims
///     hard destruction — the confirmation copy says
///     "إلغاء تفعيل" and explains the device stays in the account
///     archive.
class _DeviceDetailMenu extends ConsumerStatefulWidget {
  const _DeviceDetailMenu({
    required this.device,
    required this.onChanged,
    required this.onDeleted,
  });

  final DeviceDetail device;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_DeviceDetailMenu> createState() =>
      _DeviceDetailMenuState();
}

class _DeviceDetailMenuState extends ConsumerState<_DeviceDetailMenu> {
  bool _busy = false;

  Future<void> _openEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditDeviceScreen(device: widget.device),
      ),
    );
    if (saved == true) {
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ تعديلات الجهاز.')),
        );
      }
    }
  }

  Future<void> _confirmAndDeactivate() async {
    final deviceName = widget.device.name.isNotEmpty
        ? widget.device.name
        : 'هذا الجهاز';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('إلغاء تفعيل الجهاز؟'),
        content: Text(
          'سيتم إلغاء تفعيل «$deviceName» وإزالته من القائمة النشطة. '
          'يبقى الجهاز محفوظاً في حسابك ويمكن للدعم إعادة تفعيله عند الحاجة. '
          'لا تتأثر القراءات التاريخية ولا الإشعارات السابقة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('إلغاء التفعيل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(devicesRepositoryProvider)
          .deactivate(deviceId: widget.device.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إلغاء تفعيل الجهاز.')),
      );
      widget.onDeleted();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('تعذّر إلغاء التفعيل: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'إجراءات',
      icon: const Icon(Icons.more_vert),
      onSelected: (key) {
        switch (key) {
          case 'edit':
            _openEdit();
            break;
          case 'delete':
            _confirmAndDeactivate();
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('تعديل'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.power_settings_new, color: ZynColors.danger),
            title: Text(
              'إلغاء تفعيل الجهاز',
              style: TextStyle(color: ZynColors.danger),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}


// ── v52: alerts + history ──────────────────────────────────────────

/// v52: high-visibility list of server-derived alerts. Reads
/// [deviceAlertsProvider] for the device. Renders:
///   * loading  → 0-height (the parent already has a sync-status hero,
///                no need for a second skeleton during transient load)
///   * empty    → 0-height (no alerts ≠ a state worth showing)
///   * error    → 0-height (silent — the parent's RefreshIndicator
///                handles error UX; we don't want a second error banner)
///   * has data → tonal warning/info card with one row per alert,
///                Arabic localised via [alertMessageArabic] /
///                [alertTitleArabic]
///
/// Section is **strictly additive** — when there are no alerts the
/// detail layout looks identical to the pre-v52 version.
class _AlertsCard extends ConsumerWidget {
  const _AlertsCard({required this.deviceId});
  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deviceAlertsProvider(deviceId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (alerts) {
        if (alerts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(label: 'تنبيهات الجهاز'),
                const SizedBox(height: 10),
                for (var i = 0; i < alerts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _AlertRow(alert: alerts[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final DeviceAlert alert;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForLevel(alert.level);
    final icon = _iconForLevel(alert.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alertTitleArabic(alert),
                  style: TextStyle(
                    color: tone,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alertMessageArabic(alert),
                  style: const TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _toneForLevel(String level) {
    switch (level) {
      case 'warning':
        return ZynColors.warning;
      case 'critical':
      case 'danger':
        return ZynColors.danger;
      case 'info':
      default:
        return ZynColors.primary700;
    }
  }

  IconData _iconForLevel(String level) {
    switch (level) {
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'critical':
      case 'danger':
        return Icons.error_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }
}

/// v52: compact history card. Lists the most recent readings (top N)
/// from `GET /api/v1/devices/<id>/history`. v52 keeps it intentionally
/// simple — no charts, no per-range filtering, no pagination UI. If
/// the user wants more than the visible window, they can pull-to-
/// refresh (which invalidates the parent detail and this card along
/// with it) or expand via "تحميل المزيد".
class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.deviceId});
  final int deviceId;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  /// Initial visible window — small enough that the card stays
  /// compact, large enough to feel useful. The backend page is 100
  /// rows by default, so this is purely a presentation cap.
  static const int _initialVisible = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deviceHistoryProvider(widget.deviceId));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'سجل القراءات'),
          const SizedBox(height: 4),
          const Text(
            'آخر قراءات الجهاز خلال الأيام السابقة.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: AppLoading(message: 'جارٍ تحميل القراءات...'),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AppErrorState(
                error: err is ApiException
                    ? err
                    : ApiException(
                        message: 'تعذّر تحميل سجل القراءات.',
                        kind: ApiErrorKind.unknown,
                      ),
                onRetry: () => ref.invalidate(
                  deviceHistoryProvider(widget.deviceId),
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا توجد قراءات محفوظة في النافذة الافتراضية '
                    '(آخر سبعة أيام).',
                    style: TextStyle(
                      color: ZynColors.inkSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                );
              }
              final visible = _expanded
                  ? rows
                  : rows.take(_initialVisible).toList(growable: false);
              final remaining = rows.length - visible.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        color: ZynColors.line,
                        height: 14,
                        thickness: 1,
                      ),
                    _HistoryRow(reading: visible[i]),
                  ],
                  if (remaining > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _expanded = true),
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text('تحميل المزيد ($remaining)'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One history row. Renders the timestamp + a small grid of headline
/// power values + the backend `status_text` when present. Numbers use
/// the same Western-digit format as the rest of the app for
/// consistency.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.reading});
  final DeviceReadingRow reading;

  @override
  Widget build(BuildContext context) {
    final time = formatDateTime(reading.createdAt) ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_outlined,
                size: 13, color: ZynColors.muted),
            const SizedBox(width: 6),
            Text(
              time,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _MiniMetric(
              label: 'شمسي',
              value: '${reading.solarPowerW.round()} واط',
            ),
            _MiniMetric(
              label: 'استهلاك',
              value: '${reading.homeLoadW.round()} واط',
            ),
            _MiniMetric(
              label: 'البطارية',
              value: '${reading.batterySocPercent.round()}%',
            ),
          ],
        ),
        if (reading.statusText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            reading.statusText,
            style: const TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: ZynColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: ZynColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// v50: compact "زامن الآن" button. Reuses the backend
/// `sync_now_internal` path via `POST /api/mobile/devices/<id>/sync-now`
/// so the user can verify connectivity immediately without waiting
/// for the next scheduler tick. Honest feedback:
///   * success → SnackBar "تمت المزامنة. تم تحديث حالة الجهاز." and
///     invalidate `deviceDetailProvider(deviceId)` so the
///     freshly-set `connection_status='ok'` / `last_connected_at`
///     surface on the next rebuild.
///   * failure → SnackBar with the backend's Arabic error message
///     (`setup_not_ready` / `sync_failed` / `device_inactive`). The
///     UI never claims "متصل" — that state only flips when the
///     refreshed detail payload actually says so.
class _SyncNowButton extends ConsumerStatefulWidget {
  const _SyncNowButton({required this.deviceId});
  final int deviceId;

  @override
  ConsumerState<_SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<_SyncNowButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(devicesRepositoryProvider).submitSyncNow(
            deviceId: widget.deviceId,
          );
      if (!mounted) return;
      ref.invalidate(deviceDetailProvider(widget.deviceId));
      // v52: a fresh reading just landed — pull the new history row
      // and re-derived alerts at the same time.
      ref.invalidate(deviceHistoryProvider(widget.deviceId));
      ref.invalidate(deviceAlertsProvider(widget.deviceId));
      messenger.showSnackBar(const SnackBar(
        content: Text('تمت المزامنة. تم تحديث حالة الجهاز.'),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('تعذّر المزامنة: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46.0,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 18),
        label: Text(_busy ? 'جارٍ المزامنة...' : 'زامن الآن'),
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
          color: ZynColors.primary50,
          borderRadius: BorderRadius.circular(ZynRadii.card),
          border: Border.all(color: ZynColors.primary500.withValues(alpha: 0.40)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: ZynColors.primary700, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'هذا هو جهازك النشط الحالي.',
                style: TextStyle(
                  color: ZynColors.primary700,
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
      height: 46.0 + 4,
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
        color: ZynColors.ink,
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
                color: ZynColors.muted,
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
                color: ZynColors.ink,
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
