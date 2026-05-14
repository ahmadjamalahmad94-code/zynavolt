import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/statistics_models.dart';
import '../data/statistics_repository.dart';

/// v102 DS v1 — الإحصاءات.
///
/// Subscriber-facing day/month view over `/api/v1/devices/<id>/statistics`.
/// View selector pills + anchor picker; totals card + per-bucket detail
/// table. PDF/CSV export is web-only (honest note at the bottom).
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
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

    return ZynScreen(
      hero: ZynPageHero(
        title: 'الإحصاءات',
        subtitle: 'تفاصيل الإنتاج والاستهلاك يومياً وشهرياً.',
        trailing: ZynHeroActionButton(
          icon: Icons.today_outlined,
          tooltip: 'العودة لليوم',
          onPressed: _resetToToday,
        ),
      ),
      child: deviceId == null
          ? const _NoDeviceState()
          : _buildBody(deviceId),
    );
  }

  Widget _buildBody(int deviceId) {
    final query = StatisticsQuery(
      deviceId: deviceId,
      view: _view,
      anchor: _anchorIso,
    );
    final snap = ref.watch(statisticsProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ViewSelector(view: _view, onChanged: _setView),
        const SizedBox(height: ZynSpacing.md),
        _AnchorRow(anchorIso: _anchorIso, onPick: _pickAnchor),
        const SizedBox(height: ZynSpacing.md),
        snap.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: ZynSpacing.xxl),
            child: AppLoading(message: 'جارٍ تحميل الإحصاءات...'),
          ),
          error: (err, _) => AppErrorState(
            error: err is ApiException
                ? err
                : ApiException(
                    message: 'تعذّر تحميل الإحصاءات.',
                    kind: ApiErrorKind.unknown,
                  ),
            onRetry: () => ref.invalidate(statisticsProvider(query)),
          ),
          data: _buildSnapshot,
        ),
      ],
    );
  }

  Widget _buildSnapshot(StatisticsSnapshot s) {
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
        _TotalsCard(totals: s.totals),
        const SizedBox(height: ZynSpacing.md),
        if (s.empty) const _EmptyState() else _BucketsCard(buckets: s.buckets, view: s.view),
        const SizedBox(height: ZynSpacing.lg),
        const _HonestNote(),
      ],
    );
  }
}

// ─── View selector ───────────────────────────────────────────────

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

// ─── Anchor row ─────────────────────────────────────────────────

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

// ─── Totals card ────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final StatisticsTotals totals;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إجماليات الفترة',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          _TotalRow(
            label: 'الإنتاج',
            valueKwh: totals.productionKwh,
            icon: Icons.wb_sunny_outlined,
            tone: ZynColors.warning,
          ),
          _TotalRow(
            label: 'الاستهلاك',
            valueKwh: totals.consumptionKwh,
            icon: Icons.home_outlined,
            tone: ZynColors.primary500,
          ),
          _TotalRow(
            label: 'شحن البطارية',
            valueKwh: totals.batteryInKwh,
            icon: Icons.battery_charging_full_outlined,
            tone: ZynColors.success,
          ),
          _TotalRow(
            label: 'استيراد الشبكة',
            valueKwh: totals.gridInKwh,
            icon: Icons.bolt_outlined,
            tone: ZynColors.muted,
          ),
          const SizedBox(height: 8),
          const Divider(color: ZynColors.lineSoft, height: 1, thickness: 1),
          const SizedBox(height: 8),
          _MetaRow(
            label: 'متوسط الشحنة %',
            value: totals.avgBatterySocPercent.toStringAsFixed(1),
          ),
          _MetaRow(
            label: 'ذروة الإنتاج (واط)',
            value: totals.maxSolarW.toStringAsFixed(0),
          ),
          _MetaRow(label: 'عدد القراءات', value: totals.samples.toString()),
          if (totals.dataGaps > 0)
            _MetaRow(label: 'فجوات البيانات', value: totals.dataGaps.toString()),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.valueKwh,
    required this.icon,
    required this.tone,
  });

  final String label;
  final double valueKwh;
  final IconData icon;
  final Color tone;

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
            '${valueKwh.toStringAsFixed(2)} kWh',
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZynColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Buckets card ───────────────────────────────────────────────

class _BucketsCard extends StatelessWidget {
  const _BucketsCard({required this.buckets, required this.view});

  final StatisticsBuckets buckets;
  final String view;

  @override
  Widget build(BuildContext context) {
    final count = [
      buckets.labels.length,
      buckets.productionKwh.length,
      buckets.consumptionKwh.length,
    ].reduce((a, b) => a < b ? a : b);

    final unitLabel = view == 'day' ? 'كل ساعة' : 'كل يوم';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'التفاصيل',
                style: TextStyle(
                  color: ZynColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                unitLabel,
                style: const TextStyle(
                  color: ZynColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.sm),
          const _BucketHeader(),
          const SizedBox(height: 4),
          const Divider(color: ZynColors.lineSoft, height: 1, thickness: 1),
          const SizedBox(height: 4),
          for (var i = 0; i < count; i++)
            _BucketRow(
              label: buckets.labels[i],
              production: buckets.productionKwh[i],
              consumption: buckets.consumptionKwh[i],
            ),
        ],
      ),
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: ZynColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    return const Row(
      children: [
        Expanded(flex: 3, child: Text('الفترة', style: style)),
        Expanded(
          flex: 3,
          child: Text('الإنتاج (kWh)',
              style: style, textAlign: TextAlign.end),
        ),
        SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text('الاستهلاك (kWh)',
              style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.label,
    required this.production,
    required this.consumption,
  });

  final String label;
  final double production;
  final double consumption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              production.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              consumption.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty + honest note ───────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, color: ZynColors.muted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد قراءات كافية لهذه الفترة. جرّب تاريخاً آخر أو انتظر '
              'تجميع المزيد من القراءات.',
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

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'هذه شاشة الإحصاءات الأساسية. الرسم البياني التفصيلي وعرض السنة '
      'سيُضافان في تحديث لاحق. لتنزيل تقرير قابل للطباعة استخدم نسخة الويب.',
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
    return const ZynEmptyState(
      icon: Icons.solar_power_outlined,
      title: 'لا يوجد جهاز محدّد',
      subtitle:
          'لعرض الإحصاءات، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
          'ثم اختره كجهاز فعّال.',
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
