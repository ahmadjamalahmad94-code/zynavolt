import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/statistics_models.dart';
import '../data/statistics_repository.dart';

/// v57 — minimal subscriber-facing statistics screen.
///
/// Structural baseline only: this screen establishes the route, the
/// data-layer wiring to the v56 `/api/v1/devices/<id>/statistics`
/// endpoint, and an honest read-only render of the totals + buckets.
/// No chart library is pulled in — the buckets are listed in a small
/// scrolling table. A future v-series can swap the table for a real
/// chart without changing the data path.
///
/// Scope (matching the v56 backend contract):
///   * `view`   — `day` / `month` only.  `year` is deferred.
///   * `anchor` — single `YYYY-MM-DD` date passed to the backend.
///                Phase-1 navigator is simple "today / pick" only;
///                step-prev / step-next will arrive once the
///                screen earns a real chart.
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
        title: const Text('الإحصاءات'),
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
    final query = StatisticsQuery(
      deviceId: deviceId,
      view: _view,
      anchor: _anchorIso,
    );
    final snap = ref.watch(statisticsProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(statisticsProvider(query));
        await ref.read(statisticsProvider(query).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ViewSelector(view: _view, onChanged: _setView),
          const SizedBox(height: 12),
          _AnchorRow(
            anchorIso: _anchorIso,
            onPick: _pickAnchor,
          ),
          const SizedBox(height: 12),
          snap.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
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
      ),
    );
  }

  Widget _buildSnapshot(StatisticsSnapshot s) {
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
        _TotalsCard(totals: s.totals),
        const SizedBox(height: 12),
        if (s.empty)
          const _EmptyState()
        else
          _BucketsCard(buckets: s.buckets, view: s.view),
        const SizedBox(height: 18),
        const _HonestNote(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────

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

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final StatisticsTotals totals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إجماليات الفترة',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _TotalRow(
            label: 'الإنتاج',
            valueKwh: totals.productionKwh,
            icon: Icons.wb_sunny_outlined,
            tone: AppTheme.warning,
          ),
          _TotalRow(
            label: 'الاستهلاك',
            valueKwh: totals.consumptionKwh,
            icon: Icons.home_outlined,
            tone: AppTheme.indigoPrimary,
          ),
          _TotalRow(
            label: 'شحن البطارية',
            valueKwh: totals.batteryInKwh,
            icon: Icons.battery_charging_full_outlined,
            tone: AppTheme.success,
          ),
          _TotalRow(
            label: 'استيراد الشبكة',
            valueKwh: totals.gridInKwh,
            icon: Icons.bolt_outlined,
            tone: AppTheme.muted,
          ),
          const Divider(height: 18),
          _MetaRow(
            label: 'متوسط الشحنة %',
            value: totals.avgBatterySocPercent.toStringAsFixed(1),
          ),
          _MetaRow(
            label: 'ذروة الإنتاج (واط)',
            value: totals.maxSolarW.toStringAsFixed(0),
          ),
          _MetaRow(
            label: 'عدد القراءات',
            value: totals.samples.toString(),
          ),
          if (totals.dataGaps > 0)
            _MetaRow(
              label: 'فجوات البيانات',
              value: totals.dataGaps.toString(),
            ),
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
            '${valueKwh.toStringAsFixed(2)} kWh',
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
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'التفاصيل',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                unitLabel,
                style: const TextStyle(
                  color: AppTheme.faintMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _BucketHeader(),
          const Divider(height: 14),
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
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppTheme.faintMuted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    return Row(
      children: const [
        Expanded(flex: 3, child: Text('الفترة', style: style)),
        Expanded(
          flex: 3,
          child: Text('الإنتاج (kWh)', style: style, textAlign: TextAlign.end),
        ),
        SizedBox(width: 8),
        Expanded(
          flex: 3,
          child:
              Text('الاستهلاك (kWh)', style: style, textAlign: TextAlign.end),
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
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              production.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
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
                color: AppTheme.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: AppTheme.faintMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد قراءات كافية لهذه الفترة. جرّب تاريخاً آخر أو انتظر '
              'تجميع المزيد من القراءات.',
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

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'هذه شاشة الإحصاءات الأساسية. الرسم البياني التفصيلي وعرض السنة '
      'سيُضافان في تحديث لاحق. لتنزيل تقرير قابل للطباعة استخدم نسخة الويب '
      'حالياً.',
      style: const TextStyle(
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
              'لعرض الإحصاءات، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
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
