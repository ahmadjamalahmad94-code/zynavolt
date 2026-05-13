/// v91 — mobile plan-change preview/confirm screen.
///
/// Mirrors the web `subscriber_plan_change_preview.html` flow:
///   1. Fetch `/api/mobile/account/plan-change/preview?plan_id=…`.
///   2. Render the policy-aware narrative (downgrade / upgrade /
///      lateral).
///   3. Let the subscriber commit to a scenario via
///      `/api/mobile/account/plan-change/confirm`.
///   4. For `payment_required` outcomes, call
///      `/api/mobile/account/plan-change/checkout` and launch the
///      Stripe-hosted URL via `url_launcher` (external browser).
///   5. For `applied` outcomes, invalidate the account snapshot so
///      the calling screen refreshes in-place.
///
/// Policy correctness is enforced by the backend (downgrade cannot
/// produce a refund). The UI hides the forbidden choice so the
/// subscriber never sees a path that would be refused.
library plan_change_preview_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import '../data/plan_change_models.dart';

class PlanChangePreviewScreen extends ConsumerStatefulWidget {
  const PlanChangePreviewScreen({
    super.key,
    required this.targetPlan,
  });

  final AvailablePlan targetPlan;

  @override
  ConsumerState<PlanChangePreviewScreen> createState() =>
      _PlanChangePreviewScreenState();
}

class _PlanChangePreviewScreenState
    extends ConsumerState<PlanChangePreviewScreen> {
  late Future<PlanChangePreview> _previewFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _load();
  }

  Future<PlanChangePreview> _load() {
    final repo = ref.read(accountRepositoryProvider);
    final planId = widget.targetPlan.id;
    if (planId == null) {
      throw ApiException(
        message: 'الخطة المطلوبة غير صالحة.',
        kind: ApiErrorKind.validation,
        code: 'plan_id_invalid',
      );
    }
    return repo.previewPlanChange(planId: planId);
  }

  Future<void> _refresh() async {
    setState(() {
      _previewFuture = _load();
    });
    await _previewFuture;
  }

  Future<void> _onConfirm(PlanChangePreview preview, String mode) async {
    if (_submitting) return;
    final confirmed = await _showConfirmDialog(preview, mode);
    if (confirmed != true) return;
    final planId = widget.targetPlan.id;
    if (planId == null) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final result = await repo.confirmPlanChange(planId: planId, mode: mode);
      if (!mounted) return;
      if (result.needsPayment && result.caseId != null) {
        await _handlePaymentRequired(result);
      } else if (result.isApplied) {
        _showSuccessAndPop(
          'تم تطبيق تغيير الخطة بنجاح.',
        );
      } else if (result.isBlocked) {
        _showError(_arabicBlockedReason(result.blockedReason));
      } else {
        _showError('استجابة غير متوقّعة من الخادم.');
      }
    } on ApiException catch (exc) {
      if (!mounted) return;
      _showError(_arabicApiError(exc));
    } catch (_) {
      if (!mounted) return;
      _showError('حدث خطأ غير متوقّع. الرجاء المحاولة مجدداً.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handlePaymentRequired(PlanChangeConfirmResult result) async {
    final repo = ref.read(accountRepositoryProvider);
    try {
      final session = await repo.createCheckoutSession(caseId: result.caseId!);
      if (!mounted) return;
      final uri = Uri.tryParse(session.url);
      if (uri == null) {
        _showError('تعذّر فتح صفحة الدفع.');
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        _showError('تعذّر فتح صفحة الدفع.');
        return;
      }
      // Inform the subscriber and bounce them back to the account
      // screen — the pending-invoice banner there will let them
      // resume the payment if they need to.
      _showSuccessAndPop(
        'تم فتح صفحة الدفع. أكمل الدفع لإتمام تغيير الخطة.',
      );
    } on ApiException catch (exc) {
      if (!mounted) return;
      _showError(_arabicApiError(exc));
    }
  }

  void _showSuccessAndPop(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text(message),
        duration: const Duration(seconds: 4),
      ));
    // Signal the caller to refresh + close this screen.
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        content: Text(message),
      ));
  }

  String _arabicApiError(ApiException exc) {
    switch (exc.code) {
      case 'auth_required':
        return 'انتهت الجلسة. الرجاء تسجيل الدخول مجدداً.';
      case 'plan_id_invalid':
      case 'plan_id_required':
        return 'الخطة المطلوبة غير صالحة.';
      case 'no_active_subscription':
        return 'لا يوجد اشتراك فعّال.';
      case 'target_plan_unavailable':
        return 'الخطة المطلوبة غير متاحة.';
      case 'same_plan_already_active':
        return 'أنت على هذه الخطة بالفعل.';
      case 'downgrade_same_duration_not_allowed':
        return 'النزول إلى خطة أرخص لا يُرجع مبالغ — استخدم خيار التحويل إلى أيام أكثر.';
      case 'unknown_mode':
        return 'وضع التسعير غير معروف.';
      case 'no_pending_invoice':
        return 'لا يوجد مبلغ مستحق على هذا الطلب.';
      case 'case_not_pending_payment':
        return 'هذا الطلب ليس بانتظار الدفع.';
      case 'stripe_not_ready':
        return 'خدمة الدفع غير مهيّأة. الرجاء التواصل مع الدعم.';
      case 'stripe_error':
        return 'تعذّر إنشاء جلسة الدفع. حاول مجدداً.';
      case 'internal_error':
        return 'حدث خطأ غير متوقّع. الرجاء المحاولة مجدداً.';
      default:
        return exc.message.isNotEmpty
            ? exc.message
            : 'تعذّر إتمام العملية.';
    }
  }

  String _arabicBlockedReason(String? reason) {
    return _arabicApiError(
      ApiException(
        message: '',
        kind: ApiErrorKind.validation,
        code: reason,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
      PlanChangePreview preview, String mode) async {
    final scenario =
        mode == 'same_duration' ? preview.sameDuration : preview.reducedDays;
    final amountLine = scenario.amount > 0
        ? 'سيتم إنشاء طلب دفع بمبلغ ${scenario.amount.toStringAsFixed(2)} ${preview.currency}.'
        : 'لا يوجد مبلغ مستحق.';
    final daysLine =
        'الأيام بعد التغيير: ${scenario.targetDays} يوماً على ${preview.targetPlanLabel}.';
    final extraWarning = (preview.policyKind == 'upgrade' && mode == 'reduced_days')
        ? 'ملاحظة: ستحصل على أيام أقل من رصيدك الحالي.'
        : null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد تغيير الخطة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(daysLine),
              const SizedBox(height: 8),
              Text(amountLine),
              if (extraWarning != null) ...[
                const SizedBox(height: 8),
                Text(
                  extraWarning,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تغيير الخطة'),
        ),
        body: FutureBuilder<PlanChangePreview>(
          future: _previewFuture,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AppLoading(message: 'جاري حساب الأيام...');
            }
            if (snap.hasError) {
              final exc = snap.error;
              final apiExc = exc is ApiException
                  ? exc
                  : ApiException(
                      message: 'تعذّر تحميل تفاصيل تغيير الخطة.',
                      kind: ApiErrorKind.unknown,
                    );
              return AppErrorState(
                error: apiExc,
                onRetry: _refresh,
              );
            }
            final preview = snap.data!;
            if (preview.isBlocked) {
              return _BlockedView(
                blockedReason: preview.blockedReason!,
                arabicMessage: _arabicBlockedReason(preview.blockedReason),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _PreviewBody(
                preview: preview,
                submitting: _submitting,
                onConfirm: (mode) => _onConfirm(preview, mode),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Body widgets ────────────────────────────────────────────────────


class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.preview,
    required this.submitting,
    required this.onConfirm,
  });

  final PlanChangePreview preview;
  final bool submitting;
  final ValueChanged<String> onConfirm;

  @override
  Widget build(BuildContext context) {
    final policy = preview.policyKind;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _PolicyHero(policy: policy, preview: preview),
        const SizedBox(height: 14),
        _DecisionExplainer(preview: preview),
        const SizedBox(height: 14),
        _SituationSummary(preview: preview),
        const SizedBox(height: 14),
        if (policy == 'downgrade') ...[
          _IneligibleSameDurationCard(preview: preview),
          const SizedBox(height: 12),
          _ScenarioCard(
            preview: preview,
            scenario: preview.reducedDays,
            isPrimary: true,
            ctaLabel: 'تحويل إلى أيام أكثر',
            ctaColor: const Color(0xFF059669),
            submitting: submitting,
            onConfirm: () => onConfirm('reduced_days'),
            title: 'تحويل قيمتي إلى أيام أكثر',
            tag: 'الموصى به',
            description:
                'تتحوّل قيمتك المتبقّية (${preview.reducedDays.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}) '
                'إلى ${preview.reducedDays.targetDays} يوماً على الخطة الأرخص. '
                'لا تتحرّك أي مبالغ ولا يتم إرجاع شيء.',
          ),
        ] else if (policy == 'upgrade') ...[
          _ScenarioCard(
            preview: preview,
            scenario: preview.sameDuration,
            isPrimary: false,
            ctaLabel: preview.sameDuration.amount > 0
                ? 'إنشاء طلب دفع للفرق'
                : 'تطبيق الآن',
            ctaColor: const Color(0xFFEA580C),
            submitting: submitting,
            onConfirm: () => onConfirm('same_duration'),
            title: 'الخيار أ — إبقاء أيامي مع دفع الفرق',
            tag: 'الخيار أ',
            description:
                'تحتفظ بـ ${preview.remainingDays} يوماً المتبقّية، وتدفع فرق السعر '
                '(${preview.sameDuration.amount.toStringAsFixed(2)} ${preview.currency}) '
                'لإتمام التحويل. الخطة تُطبَّق بعد الدفع.',
          ),
          const SizedBox(height: 12),
          _ScenarioCard(
            preview: preview,
            scenario: preview.reducedDays,
            isPrimary: true,
            ctaLabel: 'تطبيق مع أيام أقل',
            ctaColor: const Color(0xFF059669),
            submitting: submitting,
            onConfirm: () => onConfirm('reduced_days'),
            title: 'الخيار ب — أيام أقل بدون دفع إضافي',
            tag: 'الخيار ب',
            description:
                'تُحفظ قيمتك المتبقّية (${preview.reducedDays.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}) '
                'ويُعاد تسعيرها على الخطة الأعلى، فتحصل على ${preview.reducedDays.targetDays} يوماً دون أي مبلغ إضافي.',
          ),
        ] else ...[
          _ScenarioCard(
            preview: preview,
            scenario: preview.sameDuration,
            isPrimary: true,
            ctaLabel: 'تطبيق التحويل',
            ctaColor: const Color(0xFF6366F1),
            submitting: submitting,
            onConfirm: () => onConfirm('same_duration'),
            title: 'تحويل مكافئ',
            tag: 'مباشر',
            description:
                'الخطتان متقاربتان في السعر اليومي — يتم التحويل مباشرة بدون دفع وبدون تعديل في الأيام.',
          ),
        ],
        const SizedBox(height: 18),
        _HelpHint(),
      ],
    );
  }
}

class _PolicyHero extends StatelessWidget {
  const _PolicyHero({required this.policy, required this.preview});
  final String policy;
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final color = policy == 'downgrade'
        ? const Color(0xFF059669)
        : policy == 'upgrade'
            ? const Color(0xFFEA580C)
            : const Color(0xFF6366F1);
    final icon = policy == 'downgrade'
        ? '↓'
        : policy == 'upgrade'
            ? '↑'
            : '↔';
    final title = policy == 'downgrade'
        ? 'الانتقال إلى خطة أرخص — أيام أكثر'
        : policy == 'upgrade'
            ? 'الانتقال إلى خطة أعلى — اختر طريقة الانتقال'
            : 'تغيير الخطة';
    final subtitle = policy == 'downgrade'
        ? 'تُحوَّل قيمتك المتبقّية إلى أيام إضافية على الخطة الجديدة. لا يتم إرجاع أي مبلغ.'
        : policy == 'upgrade'
            ? 'احتفظ بأيامك وادفع الفرق، أو خذ أياماً أقل دون أي مبلغ إضافي.'
            : 'تحويل مباشر بدون دفع وبدون تعديل في الأيام.';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.04)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
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

class _DecisionExplainer extends StatelessWidget {
  const _DecisionExplainer({required this.preview});
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final policy = preview.policyKind;
    final color = policy == 'downgrade'
        ? const Color(0xFF059669)
        : policy == 'upgrade'
            ? const Color(0xFFEA580C)
            : const Color(0xFF6366F1);
    final perDay =
        preview.reducedDays.extra.targetPerDayPrice?.toStringAsFixed(4) ?? '—';
    final remainingValue =
        preview.sameDuration.currentRemainingValue.toStringAsFixed(2);
    final hint = policy == 'downgrade'
        ? 'لديك $remainingValue ${preview.currency} قيمة متبقّية. '
            'الخطة الجديدة تكلّفك $perDay ${preview.currency} فقط في اليوم، '
            'فينتج عن قسمة قيمتك على هذا السعر أيام أكثر. '
            'لهذا تحصل على ${preview.reducedDays.targetDays} يوماً.'
        : policy == 'upgrade'
            ? 'الخطة الجديدة تكلّف $perDay ${preview.currency} في اليوم — '
                'أكثر من السعر اليومي لخطتك الحالية. لو احتفظت بأيامك ستدفع الفرق، '
                'أو تأخذ أياماً أقل دون دفع. حتى الخطة ذات السعر الكلي الأقل قد تكون "أغلى في اليوم" لو كانت دورتها أقصر.'
            : 'الخطتان متقاربتان في السعر اليومي، فالتحويل مباشر.';
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 64,
              color: color,
              margin: const EdgeInsets.only(left: 10),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 كيف يتم حساب الأيام',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SituationSummary extends StatelessWidget {
  const _SituationSummary({required this.preview});
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final s = preview.sameDuration;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KpiTile(
              label: 'الخطة الحالية',
              value: preview.currentPlanLabel,
              sub:
                  '${s.currentPlanPrice.toStringAsFixed(2)} ${preview.currency} / ${s.cycleDaysCurrent} يوم',
            ),
            _KpiTile(
              label: 'الخطة المطلوبة',
              value: preview.targetPlanLabel,
              sub:
                  '${s.targetPlanPrice.toStringAsFixed(2)} ${preview.currency} / ${s.cycleDaysTarget} يوم',
            ),
            _KpiTile(
              label: 'الأيام المتبقّية',
              value: '${preview.remainingDays}',
              sub: 'على الخطة الحالية',
            ),
            _KpiTile(
              label: 'قيمة المتبقّي',
              value:
                  '${s.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}',
              sub: 'محسوبة بالتناسب',
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.preview,
    required this.scenario,
    required this.isPrimary,
    required this.ctaLabel,
    required this.ctaColor,
    required this.submitting,
    required this.onConfirm,
    required this.title,
    required this.tag,
    required this.description,
  });

  final PlanChangePreview preview;
  final PlanChangeScenario scenario;
  final bool isPrimary;
  final String ctaLabel;
  final Color ctaColor;
  final bool submitting;
  final VoidCallback onConfirm;
  final String title;
  final String tag;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isPrimary
                  ? ctaColor.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: isPrimary ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: ctaColor.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              _ScenarioFacts(scenario: scenario, preview: preview),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ctaColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: submitting ? null : onConfirm,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(ctaLabel),
                ),
              ),
            ],
          ),
        ),
        if (isPrimary)
          Positioned(
            top: -10,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ctaColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScenarioFacts extends StatelessWidget {
  const _ScenarioFacts({required this.scenario, required this.preview});
  final PlanChangeScenario scenario;
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['الأيام المتبقّية', '${scenario.remainingDays}'],
      ['الأيام بعد التغيير', '${scenario.targetDays}'],
      [
        'قيمة المتبقّي',
        '${scenario.currentRemainingValue.toStringAsFixed(2)} ${preview.currency}',
      ],
    ];
    if (scenario.amount > 0.001) {
      rows.add([
        'المبلغ المستحق',
        '+${scenario.amount.toStringAsFixed(2)} ${preview.currency}',
      ]);
    } else {
      rows.add([
        'المبلغ المستحق',
        '0.00 ${preview.currency}',
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r[0],
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  Text(
                    r[1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: r[0] == 'المبلغ المستحق'
                          ? (scenario.amount > 0
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669))
                          : const Color(0xFF0F172A),
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

class _IneligibleSameDurationCard extends StatelessWidget {
  const _IneligibleSameDurationCard({required this.preview});
  final PlanChangePreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'خيار غير متاح: نفس الأيام مع رصيد',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'هذا المسار غير مُتاح للنزول إلى خطة أرخص. '
            'بدلاً من إرجاع المبلغ، تُحوَّل قيمتك المتبقّية إلى أيام إضافية على الخطة الجديدة (الخيار أدناه).',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HelpHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      '💬 لست متأكداً؟ تواصل مع الدعم قبل التأكيد — الفريق يرحب بمساعدتك.',
      style: TextStyle(
        fontSize: 12.5,
        color: Color(0xFF64748B),
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({
    required this.blockedReason,
    required this.arabicMessage,
  });
  final String blockedReason;
  final String arabicMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline,
                color: Color(0xFF64748B), size: 56),
            const SizedBox(height: 14),
            Text(
              arabicMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }
}
