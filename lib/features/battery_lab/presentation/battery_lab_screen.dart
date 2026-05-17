import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/state/auto_refresh.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../notifications/presentation/widgets/loads_recommendations_strip.dart';
import '../../notifications/presentation/widgets/smart_decision_card.dart';
import '../data/battery_lab_models.dart';
import '../data/battery_lab_repository.dart';

/// v102d — البطارية tab (was مختبر البطارية).
///
/// Promoted to a bottom-nav tab and now carries the Smart
/// Decision card + Loads Recommendations strip that previously
/// lived on the Notifications screen — both render with the
/// exact same look they had there.
///
/// Underneath the suggestion section, the original v100 Battery
/// Lab content stays intact:
///   * Live state hero (SoC, mode, ETA, flow).
///   * Capacity insights (capacity, reserve, stored, usable,
///     remaining to full).
///   * External AC-IN breakdown (grid vs generator + source
///     label + daily AC-IN energy).
///   * Battery details (voltage, current, temperature, cycles,
///     SOH, status, SN numbers).
///   * 48 h SoC line chart.
class BatteryLabScreen extends ConsumerWidget {
  const BatteryLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(batteryLabProvider);
    return AutoRefreshScope(
      interval: const Duration(seconds: 30),
      targets: [batteryLabProvider],
      child: ZynScreen(
        hero: const ZynPageHero(
          title: 'البطارية',
          subtitle: 'حالة البطارية، الاقتراحات الذكية، وإدارة الأحمال.',
          showBackButton: false,
        ),
        scrollable: false,
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          color: AppTheme.indigoPrimary,
          onRefresh: () async {
            ref.invalidate(batteryLabProvider);
            await ref.read(batteryLabProvider.future);
          },
          child: snap.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل البطارية...'),
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
                          message: 'تعذّر تحميل البطارية.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(batteryLabProvider),
                ),
              ],
            ),
            data: (data) => _Body(snapshot: data),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot});
  final BatteryLabSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final insights = snapshot.insights;
    final details = snapshot.details;
    final hasReading =
        insights.capacityKwh > 0 || (snapshot.latest != null);
    // v102d (owner-asked reorder): battery hero on top, then loads
    // recommendations strip, then the smart decision card. Owner's
    // mental model is "show me the battery first, then what loads
    // are safe to run, then the system's overall verdict" — the
    // suggestion bucket sat above the live state before, which
    // forced a scroll just to glance at SoC.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (!hasReading)
          const AppEmptyState(
            icon: Icons.battery_unknown_outlined,
            title: 'لا توجد قراءات للبطارية بعد',
            subtitle:
                'بمجرد وصول أول قراءة من الانفرتر، ستظهر تفاصيل البطارية هنا.',
          )
        else ...[
          _StateHero(insights: insights),
          const SizedBox(height: 14),
          const LoadsRecommendationsStrip(),
          const SizedBox(height: 14),
          const SmartDecisionCard(),
          const SizedBox(height: 14),
          _CapacitySection(insights: insights),
          const SizedBox(height: 14),
          _ExternalInputSection(insights: insights),
          const SizedBox(height: 14),
          _DetailsSection(details: details),
          const SizedBox(height: 14),
          _TrendChart(hourly: snapshot.hourly),
          const SizedBox(height: 14),
          _GeneratedAtFooter(generatedAt: snapshot.generatedAt),
        ],
      ],
    );
  }
}

// ─── State hero ────────────────────────────────────────────────────────

class _StateHero extends StatelessWidget {
  const _StateHero({required this.insights});
  final BatteryInsights insights;

  @override
  Widget build(BuildContext context) {
    final soc = insights.socPercent;
    final socColor = soc >= 50
        ? AppTheme.success
        : soc >= 20
        ? AppTheme.warning
        : AppTheme.danger;
    final (modeText, modeIcon) = insights.liveFlowDirection == 'charging'
        ? ('شحن', Icons.bolt_rounded)
        : insights.liveFlowDirection == 'discharging'
        ? ('تفريغ', Icons.south_rounded)
        : ('خامل', Icons.pause_circle_filled_rounded);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1A2E).withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1B2C4A), Color(0xFF152340), Color(0xFF0E1A2E)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        socColor.withValues(alpha: 0.40),
                        socColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                socColor,
                                socColor.withValues(alpha: 0.75),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: socColor.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.battery_charging_full_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حالة البطارية الآن',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'قراءة مباشرة من الانفرتر',
                                style: TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                socColor.withValues(alpha: 0.30),
                                socColor.withValues(alpha: 0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: socColor.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(modeIcon, size: 13, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                modeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: soc.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -2,
                                  shadows: [
                                    Shadow(
                                      color: socColor.withValues(alpha: 0.50),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' %',
                                style: TextStyle(
                                  color: socColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'التدفق الآن',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              insights.liveFlowLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Glossy capacity bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: (soc / 100).clamp(0, 1).toDouble(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      socColor.withValues(alpha: 0.85),
                                      socColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: socColor.withValues(alpha: 0.55),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Active ETA caption
                    if (insights.activeTimeCaption.isNotEmpty &&
                        insights.activeTimeLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: Color(0xCCFFFFFF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              insights.activeTimeCaption,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 12,
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insights.activeTimeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Capacity section ──────────────────────────────────────────────────

class _CapacitySection extends StatelessWidget {
  const _CapacitySection({required this.insights});
  final BatteryInsights insights;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      headerIcon: Icons.bar_chart_rounded,
      headerLabel: 'السعة والاحتياطي',
      headerSubtitle: 'لمحة عن قدرة البطارية الكلية والمخزّن حاليًا.',
      accent: AppTheme.indigoPrimary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'السعة الكلية',
                  value: '${insights.capacityKwh.toStringAsFixed(2)} kWh',
                  tone: AppTheme.indigoPrimary,
                  icon: Icons.battery_full_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'المخزّن الآن',
                  value: '${insights.storedKwh.toStringAsFixed(2)} kWh',
                  tone: AppTheme.success,
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'المتاح للاستخدام',
                  value: '${insights.usableNowKwh.toStringAsFixed(2)} kWh',
                  tone: AppTheme.cyan,
                  icon: Icons.power_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'المتبقي للامتلاء',
                  value:
                      '${insights.remainingToFullKwh.toStringAsFixed(2)} kWh',
                  tone: AppTheme.warning,
                  icon: Icons.arrow_circle_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'الاحتياطي المحجوز',
                  value: '${insights.reserveKwh.toStringAsFixed(2)} kWh',
                  tone: AppTheme.violet,
                  icon: Icons.shield_rounded,
                  helperText: '${insights.reservePercent.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: insights.liveFlowDirection == 'charging'
                      ? 'قدرة الشحن'
                      : 'قدرة التفريغ',
                  value: insights.liveFlowDirection == 'charging'
                      ? '${insights.chargePowerW.toStringAsFixed(0)} W'
                      : '${insights.dischargePowerW.toStringAsFixed(0)} W',
                  tone: insights.liveFlowDirection == 'charging'
                      ? AppTheme.success
                      : AppTheme.warning,
                  icon: Icons.electric_bolt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── External AC-IN section ────────────────────────────────────────────

class _ExternalInputSection extends StatelessWidget {
  const _ExternalInputSection({required this.insights});
  final BatteryInsights insights;

  @override
  Widget build(BuildContext context) {
    final hasGrid = insights.gridInputW > 5;
    final hasGen = insights.generatorInputW > 5;
    return _GlassCard(
      headerIcon: Icons.cable_rounded,
      headerLabel: 'الإدخال الخارجي',
      headerSubtitle: 'الشبكة والمولد، وحالة AC IN عند Deye.',
      accent: AppTheme.cyan,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'إدخال خارجي · شبكة',
                  value: '${insights.gridInputW.toStringAsFixed(0)} W',
                  tone: AppTheme.cyan,
                  icon: Icons.flash_on_rounded,
                  muted: !hasGrid,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'إدخال خارجي · مولد',
                  value: '${insights.generatorInputW.toStringAsFixed(0)} W',
                  tone: AppTheme.success,
                  icon: Icons.local_gas_station_rounded,
                  muted: !hasGen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'حالة AC IN',
                  value: insights.acInSourceLabel.isNotEmpty
                      ? insights.acInSourceLabel
                      : 'لا يوجد إدخال',
                  tone: AppTheme.indigoPrimary,
                  icon: Icons.power_settings_new_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'تصدير إلى الشبكة',
                  value: '${insights.feedInW.toStringAsFixed(0)} W',
                  tone: AppTheme.violet,
                  icon: Icons.upload_rounded,
                  muted: insights.feedInW <= 5,
                ),
              ),
            ],
          ),
          if (insights.dailyGeneratorKwh != null ||
              insights.dailyChargeKwh != null ||
              insights.dailyDischargeKwh != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (insights.dailyChargeKwh != null)
                  Expanded(
                    child: _StatTile(
                      label: 'شحنت اليوم',
                      value:
                          '${insights.dailyChargeKwh!.toStringAsFixed(2)} kWh',
                      tone: AppTheme.success,
                      icon: Icons.battery_saver_rounded,
                    ),
                  ),
                if (insights.dailyChargeKwh != null &&
                    insights.dailyDischargeKwh != null)
                  const SizedBox(width: 8),
                if (insights.dailyDischargeKwh != null)
                  Expanded(
                    child: _StatTile(
                      label: 'فرّغت اليوم',
                      value:
                          '${insights.dailyDischargeKwh!.toStringAsFixed(2)} kWh',
                      tone: AppTheme.warning,
                      icon: Icons.battery_alert_rounded,
                    ),
                  ),
              ],
            ),
          ],
          if (insights.gridRelayStatusLabel.contains('مفصول')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warning.withValues(alpha: 0.14),
                    AppTheme.warning.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insights.gridRelayStatusLabel,
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (insights.inferredExternalW != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppTheme.indigoSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.indigoPrimary.withValues(alpha: 0.16),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_rounded,
                    size: 18,
                    color: AppTheme.indigoPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تقدير من Deye: '
                      '≈ ${insights.inferredExternalW!.toStringAsFixed(0)} W'
                      '${insights.stationGenerationW != null ? '  ·  إنتاج محطة ${insights.stationGenerationW!.toStringAsFixed(0)} W' : ''}',
                      style: const TextStyle(
                        color: AppTheme.indigoPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
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

// ─── Details section ───────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.details});
  final BatteryDetails details;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      headerIcon: Icons.tune_rounded,
      headerLabel: 'تفاصيل البطارية',
      headerSubtitle: 'قياسات الجهد والتيار والحرارة وحالة الـ BMS.',
      accent: AppTheme.violet,
      child: Column(
        children: [
          if (details.batteryVoltage != null || details.batteryCurrent != null)
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'الجهد',
                    value: details.batteryVoltage != null
                        ? '${details.batteryVoltage!.toStringAsFixed(2)} V'
                        : '—',
                    tone: AppTheme.indigoPrimary,
                    icon: Icons.show_chart_rounded,
                    muted: details.batteryVoltage == null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'التيار',
                    value: details.batteryCurrent != null
                        ? '${details.batteryCurrent!.toStringAsFixed(2)} A'
                        : '—',
                    tone: AppTheme.warning,
                    icon: Icons.bolt_rounded,
                    muted: details.batteryCurrent == null,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'الحرارة',
                  value: details.batteryTemp != null
                      ? '${details.batteryTemp!.toStringAsFixed(0)} °م'
                      : '—',
                  tone: AppTheme.danger,
                  icon: Icons.thermostat_rounded,
                  muted: details.batteryTemp == null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'الدورات',
                  value: details.batteryCycles != null
                      ? details.batteryCycles!.toString()
                      : '—',
                  tone: AppTheme.cyan,
                  icon: Icons.history_rounded,
                  muted: details.batteryCycles == null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'الصحة SOH',
                  value: details.batterySoh != null
                      ? '${details.batterySoh!.toStringAsFixed(0)} %'
                      : '—',
                  tone: AppTheme.success,
                  icon: Icons.health_and_safety_rounded,
                  muted: details.batterySoh == null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'السعة Ah',
                  value: details.batteryTotalCapacityAh != null
                      ? '${details.batteryTotalCapacityAh!.toStringAsFixed(0)} Ah'
                      : '—',
                  tone: AppTheme.violet,
                  icon: Icons.bar_chart_rounded,
                  muted: details.batteryTotalCapacityAh == null,
                ),
              ),
            ],
          ),
          if (details.batteryStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.indigoSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.indigoPrimary.withValues(alpha: 0.16),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: AppTheme.indigoPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'حالة البطارية: ',
                    style: TextStyle(
                      color: AppTheme.faintMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      details.batteryStatus,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
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

// ─── Trend chart ───────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.hourly});
  final List<BatteryLabHourly> hourly;

  @override
  Widget build(BuildContext context) {
    if (hourly.isEmpty) {
      return _GlassCard(
        headerIcon: Icons.timeline_rounded,
        headerLabel: 'تغيّر نسبة البطارية',
        headerSubtitle: 'قراءة مجمّعة كل ساعة — آخر 48 ساعة.',
        accent: AppTheme.indigoBright,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: AppEmptyState(
            icon: Icons.show_chart_rounded,
            title: 'لا توجد قراءات بعد',
            subtitle: 'سيظهر الرسم البياني فور توفّر قراءات ساعية كافية.',
          ),
        ),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < hourly.length; i++)
        FlSpot(i.toDouble(), hourly[i].soc),
    ];
    final maxX = (hourly.length - 1).toDouble();
    return _GlassCard(
      headerIcon: Icons.timeline_rounded,
      headerLabel: 'تغيّر نسبة البطارية',
      headerSubtitle: 'قراءة مجمّعة كل ساعة — آخر ${hourly.length} ساعة.',
      accent: AppTheme.indigoBright,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 0,
            maxX: maxX,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 25,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.line.withValues(alpha: 0.6),
                strokeWidth: 0.6,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 25,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Text(
                      '${value.toInt()}%',
                      style: const TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: maxX / 4,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= hourly.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        hourly[i].timeLabel,
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: AppTheme.indigoBright,
                barWidth: 2.4,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.indigoBright.withValues(alpha: 0.30),
                      AppTheme.indigoBright.withValues(alpha: 0.04),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.ink.withValues(alpha: 0.95),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}%',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Generated-at footer ───────────────────────────────────────────────

class _GeneratedAtFooter extends StatelessWidget {
  const _GeneratedAtFooter({required this.generatedAt});
  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    if (generatedAt.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: AppTheme.faintMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'وقت توليد البيانات: $generatedAt',
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable: glass card + stat tile ──────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.headerIcon,
    required this.headerLabel,
    required this.headerSubtitle,
    required this.accent,
    required this.child,
  });

  final IconData headerIcon;
  final String headerLabel;
  final String headerSubtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: AppTheme.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
                child: Icon(headerIcon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerLabel,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      headerSubtitle,
                      style: const TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
    this.muted = false,
    this.helperText,
  });

  final String label;
  final String value;
  final Color tone;
  final IconData icon;
  final bool muted;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final effectiveTone = muted ? AppTheme.faintMuted : tone;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            effectiveTone.withValues(alpha: muted ? 0.04 : 0.10),
            effectiveTone.withValues(alpha: muted ? 0.02 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: effectiveTone.withValues(alpha: muted ? 0.12 : 0.22),
          width: 0.8,
        ),
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
                  gradient: LinearGradient(
                    colors: [
                      effectiveTone,
                      effectiveTone.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: effectiveTone,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (helperText != null)
                Text(
                  helperText!,
                  style: TextStyle(
                    color: effectiveTone.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
