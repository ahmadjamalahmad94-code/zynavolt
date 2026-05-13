import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/reports_models.dart';
import '../data/reports_repository.dart';

/// v60 — subscriber-facing reports summary screen.
///
/// Consumes `GET /api/v1/devices/<id>/reports/summary` (v59). Replaces
/// the v57 honest placeholder with a real read-only summary surface.
///
/// Scope (matching the v59 backend contract):
///   * `view`   — `day` / `month` only.
///   * `anchor` — single `YYYY-MM-DD` date.  Range step-prev / step-
///                next will arrive once the screen earns chart
///                navigation; for v60 the navigator is "today / pick"
///                only, mirroring the v57 statistics screen pattern.
///
/// Deliberately NOT in v60:
///   * PDF / CSV export — web-only, backend has no mobile endpoint.
///   * Smart-load suggestions — backend helper is web-session coupled.
///   * Per-bucket time-series — already in the v57 statistics screen;
///     reports surfaces the *derived* metrics instead.
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
    setState(() => _anchor = DateTime(picked.year, picked.month, picked.day));
  }

  void _resetToToday() {
    setState(() => _anchor = _todayDateOnly());
  }

  void _setView(String next) {
    if (next == _view) return;
    setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = ref.watch(effectiveDeviceIdProvider);
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            tooltip: 'العودة لليوم',
            onPressed: _resetToToday,
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: deviceId == null
            ? const _NoDeviceState()
            : _buildBody(deviceId),
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
      onRefresh: () async {
        ref.invalidate(reportsProvider(query));
        await ref.read(reportsProvider(query).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ViewSelector(view: _view, onChanged: _setView),
          const SizedBox(height: 12),
          _AnchorRow(anchorIso: _anchorIso, onPick: _pickAnchor),
          const SizedBox(height: 12),
          snap.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.titleHint,
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (s.empty)
          const _EmptyState()
        else ...[
          _EnergySummaryCard(summary: s.summary),
          const SizedBox(height: 12),
          _SharesCard(summary: s.summary),
          const SizedBox(height: 12),
          _DerivedMetricsCard(summary: s.summary),
        ],
        const SizedBox(height: 14),
        _StatisticsLink(),
        const SizedBox(height: 12),
        const _HonestNote(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── View selector + anchor row (same patterns as v57 statistics) ─────

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppTheme.indigoPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppTheme.indigoPrimary,
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppTheme.indigoPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              anchorIso,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
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

// ─── Summary cards ───────────────────────────────────────────────────

class _EnergySummaryCard extends StatelessWidget {
  const _EnergySummaryCard({required this.summary});
  final ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'إجماليات الطاقة'),
          const SizedBox(height: 10),
          _ValueRow(
            label: 'الإنتاج',
            icon: Icons.wb_sunny_outlined,
            tone: AppTheme.warning,
            value: _formatKwh(summary.productionKwh),
          ),
          _ValueRow(
            label: 'الاستهلاك',
            icon: Icons.home_outlined,
            tone: AppTheme.indigoPrimary,
            value: _formatKwh(summary.consumptionKwh),
          ),
          _ValueRow(
            label: 'شحن البطارية',
            icon: Icons.battery_charging_full_outlined,
            tone: AppTheme.success,
            value: _formatKwh(summary.batteryInKwh),
          ),
          _ValueRow(
            label: 'الاعتماد على الشبكة',
            icon: Icons.bolt_outlined,
            tone: AppTheme.muted,
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'حصص مصادر الطاقة'),
          const SizedBox(height: 4),
          const Text(
            'النسبة المئوية لما غذّى المنزل خلال هذه الفترة.',
            style: TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
          _ShareBar(
            label: 'حصة الطاقة الشمسية',
            percent: summary.solarSharePercent,
            tone: AppTheme.warning,
          ),
          const SizedBox(height: 8),
          _ShareBar(
            label: 'حصة البطارية',
            percent: summary.batterySharePercent,
            tone: AppTheme.success,
          ),
          const SizedBox(height: 8),
          _ShareBar(
            label: 'حصة الشبكة',
            percent: summary.gridSharePercent,
            tone: AppTheme.muted,
          ),
          const Divider(height: 18),
          _ValueRow(
            label: 'الاكتفاء الذاتي',
            icon: Icons.shield_outlined,
            tone: AppTheme.indigoPrimary,
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(label: 'مؤشرات إضافية'),
          const SizedBox(height: 10),
          _ValueRow(
            label: 'متوسط الحمل',
            icon: Icons.speed_outlined,
            tone: AppTheme.indigoPrimary,
            value: '${summary.averageLoadW.toStringAsFixed(1)} W',
          ),
          _ValueRow(
            label: 'الفائض الشمسي',
            icon: Icons.wb_iridescent_outlined,
            tone: AppTheme.warning,
            value: _formatKwh(summary.solarSurplusKwh),
          ),
        ],
      ),
    );
  }
}

// ─── Atoms ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppTheme.ink,
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
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
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
                  color: AppTheme.softInk,
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
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
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

// ─── Empty / footer states ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: AppTheme.faintMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد قراءات لهذه الفترة لاحتساب التقرير. جرّب تاريخاً آخر '
              'أو انتظر تجميع قراءات إضافية.',
              style: TextStyle(
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
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
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart_outlined,
                color: AppTheme.indigoPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'للاطلاع على تفاصيل لكل ساعة أو يوم، افتح شاشة الإحصاءات.',
              style: TextStyle(
                color: AppTheme.softInk,
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
        color: AppTheme.faintMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        height: 1.7,
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
      padding: const EdgeInsets.all(24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text(
              'لا يوجد جهاز محدّد',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'لعرض التقارير، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
              'ثم اختره كجهاز فعّال.',
              style: TextStyle(
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────

String _formatKwh(double v) => '${v.toStringAsFixed(2)} kWh';
