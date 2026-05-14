import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../../statistics/data/statistics_repository.dart';
import '../data/weather_models.dart';
import '../data/weather_repository.dart';
import 'widgets/day_periods_strip.dart';
import 'widgets/next_hour_card.dart';
import 'widgets/sun_times_card.dart';
import 'widgets/today_chart_strip.dart';
import 'widgets/weather_header.dart';
import 'widgets/weather_hero_card.dart';

/// v102 DS v1 — "الطاقة والطقس" subscriber screen.
///
/// Full rebuild of the v63 weather screen on the Modern Mobile SaaS
/// Energy DS. Six honest blocks, each backed by real data from
/// existing backend endpoints:
///
///   1. [WeatherHeader] — page title + active-device pill.
///   2. [WeatherHeroCard] — `weather.current` + today's kWh from
///      `/statistics?view=day` + the next-hour `solar_rating` as a
///      production verdict.
///   3. [SunTimesCard] — `weather.sun.sunrise/sunset` + a helper
///      line computed from `effective_sunrise_time` /
///      `effective_sunset_time` (when production typically kicks in
///      and when it tapers off).
///   4. [NextHourCard] — `weather.next_hour` slot (rating + advice).
///   5. [DayPeriodsStrip] — `weather.day_parts.morning/noon/afternoon`.
///   6. [TodayChartStrip] — `weather.timeline` (horizontal hourly
///      strip with per-hour temperature, cloud %, and rating).
///
/// Honesty rules carried over from v63:
///   * `available == false` → header + calm explanation card. No
///     fabricated current/sun/forecast values.
///   * Optional blocks (`current` / `sun` / `next_hour` / `day_parts`
///     / `timeline`) render only when the backend supplies them.
///   * Statistics is best-effort: if it errors or hasn't loaded, the
///     hero's production inset hides honestly rather than showing
///     `0.0 kWh`.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(weatherProvider);
    final deviceId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZynColors.pageBackdrop),
        child: SafeArea(
          child: RefreshIndicator(
            color: ZynColors.primary500,
            onRefresh: () async {
              ref.invalidate(weatherProvider);
              await ref.read(weatherProvider.future);
            },
            child: snap.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 48),
                children: const [
                  AppLoading(message: 'جارٍ تحميل بيانات الطقس...'),
                ],
              ),
              error: (err, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(ZynSpacing.lg),
                children: [
                  AppErrorState(
                    error: err is ApiException
                        ? err
                        : ApiException(
                            message: 'تعذّر تحميل بيانات الطقس.',
                            kind: ApiErrorKind.unknown,
                          ),
                    onRetry: () => ref.invalidate(weatherProvider),
                  ),
                ],
              ),
              data: (data) {
                if (data == null) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(ZynSpacing.lg),
                    children: const [
                      _WeatherHeaderFallback(),
                      SizedBox(height: ZynSpacing.lg),
                      _NoDeviceCard(),
                    ],
                  );
                }
                return _WeatherBody(snapshot: data, deviceId: deviceId);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherBody extends ConsumerWidget {
  const _WeatherBody({required this.snapshot, required this.deviceId});

  final WeatherSnapshot snapshot;
  final int? deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = snapshot.device.name;

    if (!snapshot.available) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          ZynSpacing.lg,
          ZynSpacing.md,
          ZynSpacing.lg,
          ZynSpacing.xxl,
        ),
        children: [
          WeatherHeader(deviceName: deviceName),
          const SizedBox(height: ZynSpacing.lg),
          _UnavailableCard(
            reason: snapshot.reason,
            backendMessage: snapshot.message,
          ),
          const SizedBox(height: ZynSpacing.md),
          _GeneratedAtFooter(generatedAt: snapshot.generatedAt),
        ],
      );
    }

    // Best-effort fetch of today's kWh — anchor='' so the backend
    // resolves "today" in the device's local timezone. If statistics
    // fails or hasn't loaded yet, `kwh` stays null and the hero card
    // hides the production inset honestly.
    double? kwh;
    if (deviceId != null) {
      final stats = ref.watch(
        statisticsProvider(
          StatisticsQuery(deviceId: deviceId!, view: 'day', anchor: ''),
        ),
      );
      kwh = stats.valueOrNull?.totals.productionKwh;
    }

    final current = snapshot.current!;
    final sun = snapshot.sun;
    final nextHour = snapshot.nextHour;
    final dayParts = snapshot.dayParts;
    final timeline = snapshot.timeline;

    // Verdict carried over from next-hour rating so the wording in
    // the hero stays consistent with the rest of the screen. Empty
    // string → the inset hides its verdict line.
    final verdict =
        nextHour != null && nextHour.solarRating.isNotEmpty
            ? nextHour.solarRating
            : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.xxl,
      ),
      children: [
        WeatherHeader(deviceName: deviceName),
        const SizedBox(height: ZynSpacing.lg),
        WeatherHeroCard(
          current: current,
          productionKwhToday: kwh,
          productionVerdict: verdict,
        ),
        if (sun != null) ...[
          const SizedBox(height: ZynSpacing.md),
          SunTimesCard(
            sun: sun,
            productionKickInLabel: _productionKickInLabel(sun),
            darknessInLabel: _darknessInLabel(sun),
          ),
        ],
        if (nextHour != null) ...[
          const SizedBox(height: ZynSpacing.md),
          NextHourCard(slot: nextHour),
        ],
        if (dayParts != null) ...[
          const SizedBox(height: ZynSpacing.md),
          DayPeriodsStrip(dayParts: dayParts),
        ],
        if (timeline.isNotEmpty) ...[
          const SizedBox(height: ZynSpacing.md),
          TodayChartStrip(timeline: timeline),
        ],
        const SizedBox(height: ZynSpacing.md),
        _GeneratedAtFooter(generatedAt: snapshot.generatedAt),
      ],
    );
  }

  /// Helper line for the sunrise column: when active solar
  /// production typically kicks in (effective sunrise from
  /// the backend's panel-tilt-aware computation).
  String _productionKickInLabel(WeatherSun sun) {
    final s = sun.effectiveSunriseTime;
    if (s == null || s.isEmpty) return '';
    return 'الإنتاج الفعّال يبدأ نحو $s';
  }

  /// Helper line for the sunset column: when active solar
  /// production typically tapers off.
  String _darknessInLabel(WeatherSun sun) {
    final s = sun.effectiveSunsetTime;
    if (s == null || s.isEmpty) return '';
    return 'الإنتاج يقترب من الانتهاء عند $s';
  }
}

// ─── Empty / unavailable states ──────────────────────────────────────

class _WeatherHeaderFallback extends StatelessWidget {
  const _WeatherHeaderFallback();

  @override
  Widget build(BuildContext context) =>
      const WeatherHeader(deviceName: '');
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.reason, required this.backendMessage});

  final String? reason;
  final String? backendMessage;

  String get _title {
    switch (reason) {
      case 'station_coords_unavailable':
        return 'إحداثيات الجهاز غير متوفرة';
      case 'weather_unreachable':
        return 'تعذّر الوصول إلى خدمة الطقس';
      default:
        return 'بيانات الطقس غير متوفرة';
    }
  }

  String get _detail {
    switch (reason) {
      case 'station_coords_unavailable':
        return 'لم نتمكّن من تحديد موقع المحطة من بيانات المزوّد بعد. '
            'تحقق من اكتمال إعداد الجهاز ومن أنه قام بأوّل مزامنة ناجحة.';
      case 'weather_unreachable':
        return 'خدمة الطقس الخارجية لا تستجيب في الوقت الحالي. '
            'حاول مرة أخرى بعد لحظات.';
      default:
        return backendMessage?.isNotEmpty == true
            ? backendMessage!
            : 'سيتوفّر العرض فور توفّر بيانات الطقس.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: ZynColors.muted,
            size: 20,
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _detail,
                  style: const TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
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
}

class _NoDeviceCard extends StatelessWidget {
  const _NoDeviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'لا يوجد جهاز محدّد',
            style: TextStyle(
              color: ZynColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'لعرض الطقس، أضف جهازاً واحداً على الأقل من تبويب الأجهزة، '
            'ثم اختره كجهاز فعّال.',
            style: TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedAtFooter extends StatelessWidget {
  const _GeneratedAtFooter({required this.generatedAt});
  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    if (generatedAt.isEmpty) return const SizedBox.shrink();
    var label = generatedAt;
    if (generatedAt.length >= 16) {
      label = generatedAt.substring(11, 16);
    }
    return Center(
      child: Text(
        'آخر تحديث: $label',
        style: const TextStyle(
          color: ZynColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
