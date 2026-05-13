import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../data/insights_models.dart';
import '../data/insights_repository.dart';

/// v75 — calm smart-insights card slotted into the Home screen.
///
/// Reads `insightsProvider` (already device-scoped via
/// `effectiveDeviceIdProvider`). Renders one of four states:
///
///   * loading      — small placeholder card
///   * error        — calm retry strip
///   * available=false — honest reason copy
///   * available=true  — header (icon + weather one-liner) +
///                       sunset block + advice block
///
/// No charts. No detail-page navigation. The card stays compact so
/// Home's existing flow / battery / production cards remain the
/// dominant signals.
class InsightsHomeCard extends ConsumerWidget {
  const InsightsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(insightsProvider);
    return snap.when(
      loading: () => const _InsightsLoadingCard(),
      error: (err, _) => _InsightsErrorCard(
        message: err is ApiException
            ? err.message
            : 'تعذّر تحميل التوصيات الذكية.',
        onRetry: () => ref.invalidate(insightsProvider),
      ),
      data: (data) {
        if (data == null) {
          // No effective device — Home already renders its own
          // `_NoDeviceState` above us, so we stay silent here.
          return const SizedBox.shrink();
        }
        if (!data.available) {
          return _InsightsUnavailableCard(snapshot: data);
        }
        return _InsightsAvailableCard(snapshot: data);
      },
    );
  }
}

// ─── Available state ─────────────────────────────────────────────────

class _InsightsAvailableCard extends StatelessWidget {
  const _InsightsAvailableCard({required this.snapshot});
  final InsightsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    // v99d — Smart Insights wrapped in a glossy gradient surface
    // matching the new Production card so all "secondary" cards
    // share a coherent design language (white→pale-blue gradient,
    // 22 px radius, layered shadows, hairline indigo border).
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: AppTheme.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.06),
            blurRadius: 18,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightsHeader(weather: snapshot.weatherContext),
          if (snapshot.solarPrediction != null) ...[
            const SizedBox(height: 12),
            _SunsetBlock(prediction: snapshot.solarPrediction!),
          ],
          if (snapshot.energyAdvice != null &&
              !snapshot.energyAdvice!.isEmpty) ...[
            const SizedBox(height: 12),
            _AdviceBlock(advice: snapshot.energyAdvice!),
          ],
        ],
      ),
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader({required this.weather});
  final InsightsWeatherContext? weather;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final hasWeather = w != null && !w.isEmpty;
    final cloud = w?.cloudCoverPercent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // v99d — glossy gradient icon tile to match the rest of the
        // redesigned cards. Inner-shadow effect via layered fills.
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFB347),
                Color(0xFFF59E0B),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.42),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.tips_and_updates_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'توصيات ذكية',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (hasWeather) ...[
          Text(
            w.icon.isNotEmpty ? w.icon : '🌤️',
            style: const TextStyle(fontSize: 18, height: 1.0),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _composeWeatherLine(w.conditionAr, cloud),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _composeWeatherLine(String condition, double? cloud) {
    final parts = <String>[];
    if (condition.isNotEmpty) parts.add(condition);
    if (cloud != null) parts.add('${cloud.toStringAsFixed(0)}% غيوم');
    return parts.join(' · ');
  }
}

/// Sunset / night block.
///
/// v79 polish on top of the v78 backend night-state fix: when
/// `prediction.isNight` is true the block pivots to honest
/// night-state copy — the header reads "الشمس غائبة" instead of
/// "الغروب", the sunset clock is suppressed (it's already in the
/// past today and would mislead the reader), and the
/// sunset-coupled charge-ETA / "قبل الغروب" pill stay hidden because
/// the backend mapper already forces `timeToFullHours=null` +
/// `willFullBeforeSunset=false` at night. The backend verdict and
/// advice — which v78 already pivots to sunrise-oriented copy
/// ("فترة ليلية" + "البطارية تحمل النظام حتى الشروق.") — render
/// verbatim so the user gets the canonical night message.
class _SunsetBlock extends StatelessWidget {
  const _SunsetBlock({required this.prediction});
  final InsightsSolarPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final isNight = prediction.isNight;
    final sunset = prediction.sunsetTime;
    final effective = prediction.effectiveSunsetTime;
    final ttf = prediction.timeToFullHours;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                // Same calm crescent in both modes; visually
                // appropriate at night and still reads as "solar
                // arc" during the day.
                Icons.nightlight_outlined,
                color: AppTheme.indigoPrimary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                // v79: pivot the header label at night so the user
                // doesn't read "الغروب" alongside copy that's
                // already past it.
                isNight ? 'الشمس غائبة' : 'الغروب',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Sunset clock is only meaningful while the sun is
              // still up. At night it would echo a past timestamp,
              // so we hide it. Backend v78 keeps `sunset_time`
              // populated for legacy contracts; this is a UI
              // decision, not a contract change.
              if (!isNight && sunset != null && sunset.isNotEmpty)
                Text(
                  sunset,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
          // "الإنتاج الفعّال يقترب من 18:42." is a daytime-only
          // sentence (it implies the user is approaching dusk).
          // Suppress at night.
          if (!isNight && effective != null && effective.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'الإنتاج الفعّال يقترب من $effective.',
              style: const TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
          // Charge-ETA + "قبل الغروب" pill: rendered only during the
          // day. Backend mapper already nulls `timeToFullHours` and
          // forces `willFullBeforeSunset=false` at night (v78), so
          // these guards are belt-and-braces — they also make the
          // intent crystal-clear in the widget code.
          if (!isNight && ttf != null && ttf > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.battery_charging_full_outlined,
                    color: AppTheme.success, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'الوقت المتوقّع لاكتمال الشحن: ${_formatHours(ttf)}',
                    style: const TextStyle(
                      color: AppTheme.softInk,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (prediction.willFullBeforeSunset)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Text(
                      'قبل الغروب',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (prediction.verdict != null && prediction.verdict!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              prediction.verdict!,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.55,
              ),
            ),
          ],
          if (prediction.advice != null && prediction.advice!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              prediction.advice!,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Render `1.5h` style — short Arabic phrasing for the card.
  static String _formatHours(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes دقيقة';
    }
    final h = hours.toStringAsFixed(1);
    return '$h ساعة';
  }
}

class _AdviceBlock extends StatelessWidget {
  const _AdviceBlock({required this.advice});
  final InsightsEnergyAdvice advice;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForLevel(advice.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (advice.headline.isNotEmpty)
                Expanded(
                  child: Text(
                    advice.headline,
                    style: TextStyle(
                      color: tone,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
                  ),
                ),
              _LevelBadge(level: advice.level, tone: tone),
            ],
          ),
          if (advice.detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              advice.detail,
              style: const TextStyle(
                color: AppTheme.softInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _toneForLevel(String level) {
    switch (level) {
      case 'good':
        return AppTheme.success;
      case 'caution':
      case 'warning':
        return AppTheme.warning;
      case 'critical':
        return AppTheme.danger;
      default:
        return AppTheme.muted;
    }
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.tone});
  final String level;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final label = _arabicLevelLabel(level);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static String _arabicLevelLabel(String level) {
    switch (level) {
      case 'good':
        return 'جيد';
      case 'caution':
        return 'احذر';
      case 'warning':
        return 'تنبيه';
      case 'critical':
        return 'حرج';
      default:
        return '';
    }
  }
}

// ─── Unavailable + error + loading states ────────────────────────────

class _InsightsUnavailableCard extends StatelessWidget {
  const _InsightsUnavailableCard({required this.snapshot});
  final InsightsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(snapshot.reason);
    final detail = _detailFor(snapshot.reason, snapshot.message);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: AppTheme.faintMuted,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _titleFor(String? reason) {
    switch (reason) {
      case 'reading_unavailable':
        return 'التوصيات الذكية بانتظار أول قراءة';
      case 'station_coords_unavailable':
        return 'إحداثيات الجهاز غير متوفرة';
      case 'weather_unreachable':
        return 'خدمة الطقس لا تستجيب الآن';
      default:
        return 'التوصيات الذكية غير متوفرة';
    }
  }

  static String _detailFor(String? reason, String? backendMessage) {
    switch (reason) {
      case 'reading_unavailable':
        return 'ستظهر هنا فور وصول أول مزامنة من المزوّد. لا حاجة لأي '
            'إجراء الآن.';
      case 'station_coords_unavailable':
        return 'بيانات المزوّد لا تحتوي على موقع المحطة بعد. تحقق من '
            'اكتمال إعداد الجهاز ومن نجاح أوّل مزامنة.';
      case 'weather_unreachable':
        return 'خدمة الطقس الخارجية لا تستجيب في الوقت الحالي. حاول '
            'مرة أخرى بعد لحظات.';
      default:
        final fallback = backendMessage?.trim();
        if (fallback != null && fallback.isNotEmpty) {
          return fallback;
        }
        return 'سيتم عرض التوصيات الذكية فور توفّر البيانات المطلوبة.';
    }
  }
}

class _InsightsLoadingCard extends StatelessWidget {
  const _InsightsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: AppTheme.indigoPrimary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'جارٍ تحضير التوصيات الذكية...',
              style: TextStyle(
                color: AppTheme.softInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ],
      ),
    );
  }
}

class _InsightsErrorCard extends StatelessWidget {
  const _InsightsErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.error_outline,
                    color: AppTheme.danger, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('إعادة المحاولة'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
