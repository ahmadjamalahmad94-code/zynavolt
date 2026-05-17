import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/zyn_tokens.dart';
import '../../../../core/utils/backend_time.dart';
import '../../../../core/api/api_exception.dart';
import '../../../insights/data/insights_models.dart';
import '../../../insights/data/insights_repository.dart';

/// v102 DS v1 — top-of-section card for "اقتراحات ذكية".
///
/// Renders the system's current decision pulled straight from
/// `GET /api/v1/devices/<id>/insights` (the same `smart_engine`
/// output the web dashboard uses — no mobile-side heuristics, no
/// mock data). The card carries:
///
///   * a small "القرار الحالي للنظام" eyebrow + tone-tinted icon
///   * the backend's `headline` (e.g. "🟢 مطمئن") as the title
///   * the backend's `detail` (smart_warning + smart_recommendation)
///     as the body
///   * a footer line with "آخر تحديث" and the localised time
///
/// Behaviour:
///   * Insights loading → skeleton card (subtle, single line).
///   * Insights unavailable (no reading / no weather) → compact
///     "القرار غير متوفر الآن" card with the backend's `reason`
///     translated to Arabic copy.
///   * Insights available but `energyAdvice` empty → same fallback.
class SmartDecisionCard extends ConsumerWidget {
  const SmartDecisionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insightsProvider);
    void retry() => ref.invalidate(insightsProvider);
    return async.when(
      loading: _LoadingShell.new,
      error: (err, _) {
        // v102d — surface a clearer cause whenever we can pull one
        // out of the network exception. Most "تعذّر تحميل" reports
        // turn out to be either the upstream weather/Deye API quota
        // being hit or transient network blips; the eyebrow line +
        // retry chip turn it from a dead-end into a recoverable
        // state.
        final detail = _errorDetail(err);
        return _UnavailableShell(
          title: 'تعذّر تحليل القرار الحالي',
          message: detail.message,
          hint: detail.hint,
          onRetry: retry,
        );
      },
      data: (snap) {
        if (snap == null) {
          return _UnavailableShell(
            message: 'اختَر جهازاً لعرض القرار الحالي.',
            onRetry: retry,
          );
        }
        if (!snap.available) {
          return _UnavailableShell(
            message: _reasonCopy(snap.reason),
            hint: snap.reason == 'weather_unreachable'
                ? 'قد يكون مزوّد الطقس قد بلغ حصة الاستدعاءات اليومية — يعود تلقائيًا.'
                : null,
            onRetry: retry,
          );
        }
        final advice = snap.energyAdvice;
        if (advice == null || advice.isEmpty) {
          return _UnavailableShell(
            message: 'القرار الحالي غير جاهز بعد.',
            onRetry: retry,
          );
        }
        return _DecisionBody(
          advice: advice,
          generatedAt: snap.generatedAt,
        );
      },
    );
  }

  String _reasonCopy(String? reason) {
    switch (reason) {
      case 'reading_unavailable':
        return 'لا توجد قراءة حديثة بعد لاستنتاج القرار.';
      case 'station_coords_unavailable':
        return 'بيانات الموقع للجهاز غير مكتملة — لا يمكن استنتاج قرار طقس.';
      case 'weather_unreachable':
        return 'مزوّد الطقس غير متاح الآن.';
      default:
        return 'القرار الحالي غير متوفر الآن.';
    }
  }

  ({String message, String? hint}) _errorDetail(Object err) {
    if (err is ApiException) {
      // Quota / rate-limit signals coming through ApiException —
      // map them to honest copy that names the cause so the user
      // doesn't read it as "the app is broken".
      final msg = err.message.toLowerCase();
      final isQuota = err.status == 429 ||
          msg.contains('quota') ||
          msg.contains('rate limit') ||
          msg.contains('استدعاء') ||
          msg.contains('حصة');
      if (isQuota) {
        return (
          message: 'تم بلوغ حصة استدعاءات الـ API لهذا اليوم.',
          hint:
              'سيُستأنف التحليل تلقائيًا عند تجدّد الحصة. لا حاجة لأي إجراء.',
        );
      }
      if (err.status != null && err.status! >= 500) {
        return (
          message: 'الخادم لا يستجيب الآن.',
          hint: 'حاول التحديث بعد لحظات.',
        );
      }
      return (message: err.message, hint: null);
    }
    return (
      message: 'تعذّر تحميل القرار الحالي.',
      hint: 'تحقّق من الاتصال أو حاول التحديث.',
    );
  }
}

class _DecisionBody extends StatelessWidget {
  const _DecisionBody({required this.advice, required this.generatedAt});

  final InsightsEnergyAdvice advice;
  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(advice.level);
    final time = formatBackendHm(generatedAt) ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: tone.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: ZynShadows.soft(tint: tone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: tone,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'القرار الحالي للنظام',
                      style: TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      advice.headline.isEmpty ? '—' : advice.headline,
                      style: TextStyle(
                        color: tone,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (advice.detail.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
            // Owner-tuned: drop the nested tinted box (it read as
            // "box inside box" against the white card). The detail
            // now sits inline below the headline, with a hair of
            // start-edge tone-colour to keep the visual link to
            // the card's accent without a heavy container.
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                10,
                2,
                0,
                2,
              ),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: tone.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                advice.detail,
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
            ),
          ],
          if (time.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: ZynColors.faint,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'آخر تحديث',
                  style: const TextStyle(
                    color: ZynColors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _toneFor(String level) {
    switch (level) {
      case 'good':
        return ZynColors.success;
      case 'caution':
        return ZynColors.warning;
      case 'warning':
        return ZynColors.warning;
      case 'critical':
        return ZynColors.danger;
      default:
        return ZynColors.accent;
    }
  }
}

class _UnavailableShell extends StatelessWidget {
  const _UnavailableShell({
    required this.message,
    this.title = 'القرار الحالي للنظام',
    this.hint,
    this.onRetry,
  });

  final String title;
  final String message;
  final String? hint;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.primary50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: ZynColors.primary500,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: ZynColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: ZynColors.primary50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(ZynRadii.card),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: ZynColors.primary700,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        color: ZynColors.primary700,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('إعادة المحاولة'),
                style: TextButton.styleFrom(
                  foregroundColor: ZynColors.primary700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZynColors.primary50,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ZynColors.primary50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ZynColors.primary50,
                    borderRadius: BorderRadius.circular(4),
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
