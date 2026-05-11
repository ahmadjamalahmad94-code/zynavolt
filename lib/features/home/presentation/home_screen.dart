import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../auth/data/auth_models.dart';
import '../../dashboard/data/dashboard_models.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/device_models.dart';
import '../../devices/state/selected_device_provider.dart';

/// Home tab — read-only mobile dashboard.
///
/// All numeric values come straight from the `cards` block of
/// `GET /api/mobile/dashboard`. The Flutter layer never derives, smooths,
/// or reinterprets these — it formats and renders.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final activeDeviceId = ref.watch(effectiveDeviceIdProvider);
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الرئيسية')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            // Wait for the new fetch so the spinner stays visible until done.
            await ref.read(dashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WelcomeCard(
                user: session.user,
                activeDevice: activeDevice,
              ),
              const SizedBox(height: 12),
              if (activeDeviceId == null)
                const AppCard(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: AppEmptyState(
                    icon: Icons.solar_power_outlined,
                    title: 'لم يتم اختيار جهاز بعد',
                    subtitle:
                        'اختر جهازاً من تبويب الأجهزة لعرض بياناته.',
                  ),
                )
              else
                dashboard.when(
                  loading: () => const AppCard(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: AppLoading(message: 'جارٍ تحميل بيانات الجهاز...'),
                  ),
                  error: (err, _) => AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: AppErrorState(
                      error: err is ApiException
                          ? err
                          : ApiException(
                              message: 'تعذّر تحميل بيانات اللوحة.',
                              kind: ApiErrorKind.unknown,
                            ),
                      onRetry: () => ref.invalidate(dashboardProvider),
                    ),
                  ),
                  data: (snapshot) => _DashboardBody(snapshot: snapshot),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user, required this.activeDevice});

  final AuthUser? user;
  final Device? activeDevice;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u == null
        ? ''
        : (u.fullName.isNotEmpty ? u.fullName : u.username);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مرحباً $name',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _ActiveDeviceLine(device: activeDevice),
        ],
      ),
    );
  }
}

class _ActiveDeviceLine extends StatelessWidget {
  const _ActiveDeviceLine({required this.device});
  final Device? device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    if (d == null) {
      return Row(
        children: const [
          Icon(Icons.info_outline, size: 14, color: AppTheme.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'اختر جهازاً من تبويب الأجهزة.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.solar_power_outlined,
            size: 14, color: AppTheme.indigoPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'الجهاز النشط: ${d.name.isNotEmpty ? d.name : '#${d.id}'}',
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = snapshot.cards;
    final children = <Widget>[];

    if (snapshot.scope.isAllDevices) {
      children.add(const _ScopeNotice(
        text:
            'هذه البيانات من ملخص النظام المتاح حالياً، وليست لجهاز واحد بعينه.',
      ));
      children.add(const SizedBox(height: 10));
    }

    if (snapshot.empty) {
      children.add(const AppCard(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'لا توجد قراءة متاحة بعد',
          subtitle:
              'لم يتلقَّ الخادم أي قراءات من هذا الجهاز حتى الآن. سيظهر آخر تحديث هنا فور وصوله.',
        ),
      ));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    children.addAll([
      _StatusCard(snapshot: snapshot),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.wb_sunny_outlined,
              tone: AppTheme.warning,
              label: 'الطاقة الشمسية',
              valueText: _formatWatts(cards.solarPowerW),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.home_outlined,
              tone: AppTheme.indigoPrimary,
              label: 'استهلاك المنزل',
              valueText: _formatWatts(cards.homeLoadW),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.battery_charging_full_outlined,
              tone: AppTheme.success,
              label: 'البطارية',
              valueText: _formatPercent(cards.batterySocPercent),
              subValueText: _formatWatts(cards.batteryPowerW),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: Icons.electric_meter_outlined,
              tone: AppTheme.violet,
              label: 'الشبكة',
              valueText: _formatWatts(cards.gridPowerW),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _ProductionCard(cards: cards),
      const SizedBox(height: 10),
      _LastUpdateCard(snapshot: snapshot),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppTheme.indigoPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final statusText = snapshot.latest.statusText.isNotEmpty
        ? snapshot.latest.statusText
        : '—';
    final connection = snapshot.deviceConnectionStatus.isNotEmpty
        ? snapshot.deviceConnectionStatus
        : '—';
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_outlined,
                color: AppTheme.indigoPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الحالة العامة',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'حالة الاتصال: $connection',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.tone,
    required this.label,
    required this.valueText,
    this.subValueText,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final String valueText;
  final String? subValueText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            valueText,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (subValueText != null) ...[
            const SizedBox(height: 2),
            Text(
              subValueText!,
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductionCard extends StatelessWidget {
  const _ProductionCard({required this.cards});
  final DashboardCards cards;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإنتاج',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProductionCol(
                  label: 'اليوم',
                  valueText: _formatKwh(cards.dailyProductionKwh),
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ProductionCol(
                  label: 'الشهر',
                  valueText: _formatKwh(cards.monthlyProductionKwh),
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _ProductionCol(
                  label: 'الإجمالي',
                  valueText: _formatKwh(cards.totalProductionKwh),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductionCol extends StatelessWidget {
  const _ProductionCol({required this.label, required this.valueText});
  final String label;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.faintMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valueText,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: AppTheme.line,
        margin: const EdgeInsets.symmetric(horizontal: 6),
      );
}

class _LastUpdateCard extends StatelessWidget {
  const _LastUpdateCard({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final reading = _formatIsoUtc(snapshot.latest.createdAt);
    final generated = _formatIsoUtc(snapshot.generatedAt);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: AppTheme.faintMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر قراءة: $reading',
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'وقت الاستجابة: $generated',
                  style: const TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pure formatters (display only — no business logic). ────────────────

String _formatWatts(double w) {
  if (w == 0) return '0 W';
  final sign = w < 0 ? '−' : '';
  final mag = w.abs();
  final str = mag >= 100 ? mag.toStringAsFixed(0) : mag.toStringAsFixed(1);
  return '$sign$str W';
}

String _formatPercent(double p) {
  final str = p >= 100 || p <= -100 ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  return '$str %';
}

String _formatKwh(double k) {
  if (k == 0) return '0 kWh';
  final str = k >= 100 ? k.toStringAsFixed(0) : k.toStringAsFixed(2);
  return '$str kWh';
}

String _formatIsoUtc(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  // Show the server's ISO timestamp untouched (no client-side timezone math).
  // Strip the trailing seconds-fraction if present so the row stays compact.
  final dot = iso.indexOf('.');
  return dot > 0 ? iso.substring(0, dot) : iso;
}
