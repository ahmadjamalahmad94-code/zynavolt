import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/reports_models.dart';
import '../data/reports_repository.dart';

/// v102 DS v1 — التقارير.
///
/// Read-only summary over `/api/v1/devices/<id>/reports/summary`.
/// Same `view`/`anchor` UI as Statistics; renders derived metrics
/// (energy totals + source shares + averages). PDF/CSV export is
/// web-only (honest note at the bottom).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _view = 'day';
  DateTime _anchor = _todayDateOnly();

  static DateTime _todayDateOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get _anchorIso {
    final m = _anchor.month.toString().padLeft(2, '0');
    final d = _anchor.day.toString().padLeft(2, '0');
    return '${_anchor.year}-$m-$d';
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(_anchor.year - 5, 1, 1),
      lastDate: _todayDateOnly(),
    );
    if (picked == null) return;
    setState(
        () => _anchor = DateTime(picked.year, picked.month, picked.day));
  }

  void _resetToToday() => setState(() => _anchor = _todayDateOnly());

  void _setView(String next) {
    if (next == _view) return;
    setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = ref.watch(effectiveDeviceIdProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'العودة لليوم',
            onPressed: _resetToToday,
            icon: const Icon(Icons.today_outlined,
                color: ZynColors.primary700),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.pageBackdrop),
        child: SafeArea(
          child: deviceId == null
              ? const _NoDeviceState()
              : _buildBody(deviceId),
        ),
      ),
    );
  }

  Widget _buildBody(int deviceId) {
    final query = ReportsQuery(
      deviceId: deviceId,
      view: _view,
      anchor: _anchorIso,
    );
    final snap = ref.watch(reportsProvider(query));

    return RefreshIndicator(
      color: ZynColors.primary500,
      onRefresh: () async {
        ref.invalidate(reportsProvider(query));
        await ref.read(reportsProvider(query).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZynSpacing.lg,
          ZynSpacing.md,
          ZynSpacing.lg,
          ZynSpacing.xxl,
        ),
        children: [
          _ViewSelector(view: _view, onChanged: _setView),
          const SizedBox(height: ZynSpacing.md),
          _AnchorRow(anchorIso: _anchorIso, onPick: _pickAnchor),
          const SizedBox(height: ZynSpacing.md),
          snap.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ZynSpacing.xxl),
              child: AppLoading(message: 'جارٍ تحميل التقارير...'),
            ),
            error: (err, _) => AppErrorState(
              error: err is ApiException
                  ? err
                  : ApiException(
                      message: 'تعذّر تحميل التقارير.',
                      kind: ApiErrorKind.unknown,
                    ),
              onRetry: () => ref.invalidate(reportsProvider(query)),
            ),
            data: _buildSnapshot,
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshot(ReportsSnapshot s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.titleHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: ZynSpacing.sm),
            child: Text(
              s.titleHint,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (s.empty)
          const _EmptyState()
        else ...[
          _EnergySummaryCard(summary: s.summary),
          const SizedBox(height: ZynSpacing.md),
          _SharesCard(summary: s.summary),
          const SizedBox(height: ZynSpacing.md),
          _DerivedMetricsCard(summary: s.summary),
        ],
        const SizedBox(height: ZynSpacing.md),
        const _StatisticsLink(),
        const SizedBox(height: ZynSpacing.md),
        const _HonestNote(),
      ],
    );
  }
}

// ─── View selector + anchor row ─────────────────────────────────

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          _ViewChip(
            label: 'اليوم',
            active: view == 'day',
            onTap: () => onChanged('day'),
          ),
          _ViewChip(
            label: 'الشهر',
            active: view == 'month',
            onTap: () => onChanged('month'),
          ),
        ],
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ZynRadii.tight + 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZynRadii.tight + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [ZynColors.primary500, ZynColors.primary700],
                    )
                  : null,
              borderRadius: BorderRadius.circular(ZynRadii.tight + 1),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ZynColors.primary500.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : ZynColors.primary700,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchorRow extends StatelessWidget {
  const _AnchorRow({required this.anchorIso, required this.onPick});

  final String anchorIso;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZynColors.primary50,
              borderRadius: BorderRadius.circular(ZynRadii.tight),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: ZynColors.primary700, size: 16),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Text(
              anchorIso,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('اختيار'),
          ),
        ],
      ),
    );
  }
}

// ─── Summary cards ──────────────────────────────────────────────

class _EnergySummaryCard extends StatelessWidget {
  const _EnergySummaryCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(label: 'إجماليات الطاقة'),
          const SizedBox(height: ZynSpacing.sm),
          _ValueRow(
            label: 'الإنتاج',
            icon: Icons.wb_sunny_outlined,
            tone: ZynColors.warning,
            value: _formatKwh(summary.productionKwh),
          ),
          _ValueRow(
            label: 'الاستهلاك',
            icon: Icons.home_outlined,
            tone: ZynColors.primary500,
            value: _formatKwh(summary.consumptionKwh),
          ),
          _ValueRow(
            label: 'شحن البطارية',
            icon: Icons.battery_charging_full_outlined,
            tone: ZynColors.success,
            value: _formatKwh(summary.batteryInKwh),
          ),
          _ValueRow(
            label: 'الاعتماد على الشبكة',
            icon: Icons.bolt_outlined,
            tone: ZynColors.muted,
            value: _formatKwh(summary.gridInKwh),
          ),
        ],
      ),
    );
  }
}

class _SharesCard extends StatelessWidget {
  const _SharesCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(label: 'حصص مصادر الطاقة'),
          const SizedBox(height: 4),
          const Text(
            'النسبة المئوية لما غذّى المنزل خلال هذه الفترة.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _ShareBar(
            label: 'حصة الطاقة الشمسية',
            percent: summary.solarSharePercent,
            tone: ZynColors.warning,
          ),
          const SizedBox(height: 8),
          _ShareBar(
            label: 'حصة البطارية',
            percent: summary.batterySharePercent,
            tone: ZynColors.success,
          ),
          const SizedBox(height: 8),
          _ShareBar(
            label: 'حصة الشبكة',
            percent: summary.gridSharePercent,
            tone: ZynColors.muted,
          ),
          const SizedBox(height: ZynSpacing.sm),
          const Divider(color: ZynColors.lineSoft, height: 1, thickness: 1),
          const SizedBox(height: ZynSpacing.sm),
          _ValueRow(
            label: 'الاكتفاء الذاتي',
            icon: Icons.shield_outlined,
            tone: ZynColors.primary500,
            value: '${summary.selfSufficiencyPercent.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _DerivedMetricsCard extends StatelessWidget {
  const _DerivedMetricsCard({required this.summary});

  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(label: 'مؤشرات إضافية'),
          const SizedBox(height: ZynSpacing.sm),
          _ValueRow(
            label: 'متوسط الحمل',
            icon: Icons.speed_outlined,
            tone: ZynColors.primary500,
            value: '${summary.averageLoadW.toStringAsFixed(1)} W',
          ),
          _ValueRow(
            label: 'الفائض الشمسي',
            icon: Icons.wb_iridescent_outlined,
            tone: ZynColors.warning,
            value: _formatKwh(summary.solarSurplusKwh),
          ),
        ],
      ),
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: ZynColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.icon,
    required this.tone,
    required this.value,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZynRadii.tight),
            ),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.label,
    required this.percent,
    required this.tone,
  });

  final String label;
  final double percent;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 100.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: tone,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(ZynRadii.pill),
          child: LinearProgressIndicator(
            value: clamped / 100.0,
            minHeight: 6,
            backgroundColor: tone.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
      ],
    );
  }
}

// ─── Empty / footer ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, color: ZynColors.muted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد قراءات لهذه الفترة لاحتساب التقرير. جرّب تاريخاً آخر '
              'أو انتظر تجميع قراءات إضافية.',
              style: TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsLink extends StatelessWidget {
  const _StatisticsLink();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZynGradients.iconFill(ZynColors.primary500),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          const Expanded(
            child: Text(
              'للاطلاع على تفاصيل لكل ساعة أو يوم، افتح شاشة الإحصاءات.',
              style: TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.statistics),
            child: const Text('فتح'),
          ),
        ],
      ),
    );
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'تنزيل التقارير بصيغة PDF أو CSV غير متاح على التطبيق بعد، ويمكن الوصول '
      'إليه من نسخة الويب بنفس بيانات الدخول.',
      style: TextStyle(
        color: ZynColors.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.65,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _NoDeviceState extends StatelessWidget {
  const _NoDeviceState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZynSpacing.xxl),
      child: _Card(
        child: const ZynEmptyState(
          icon: Icons.solar_power_outlined,
          title: 'لا يوجد جهاز محدّد',
          subtitle:
              'لعرض التقارير، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
              'ثم اختره كجهاز فعّال.',
        ),
      ),
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

// ─── Formatting helpers ────────────────────────────────────────

String _formatKwh(double v) => '${v.toStringAsFixed(2)} kWh';
