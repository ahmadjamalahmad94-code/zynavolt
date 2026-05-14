import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/app_session.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/account_labels.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import 'plan_change_preview_screen.dart';

/// v102 DS v1 — الحساب والاشتراك.
///
/// Read-only mirror of `GET /api/mobile/account` plus the v87
/// subscriber-driven plan-change flow (modal sheet → preview screen
/// → optional Stripe checkout). No destructive actions beyond what
/// the server advertises in `capabilities`.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(accountSnapshotProvider);

    return ZynScreen(
      hero: ZynPageHero(
        title: 'الحساب والاشتراك',
        subtitle: 'باقتك، حدودك، وأمان حسابك.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(accountSnapshotProvider),
        ),
      ),
      child: snapshot.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: AppLoading(message: 'جارٍ تحميل بيانات الحساب...'),
        ),
        error: (err, _) => AppErrorState(
          error: err is ApiException
              ? err
              : ApiException(
                  message: 'تعذّر تحميل بيانات الحساب.',
                  kind: ApiErrorKind.unknown,
                ),
          onRetry: () => ref.invalidate(accountSnapshotProvider),
        ),
        data: (account) => _AccountBody(account: account),
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.account});

  final AccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IdentityHero(account: account),
        const SizedBox(height: ZynSpacing.lg),
        const ZynSectionHeader(
          label: 'الاشتراك',
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(height: ZynSpacing.sm),
        _SubscriptionCard(subscription: account.subscription),
        if (account.pendingPlanChangeRequest != null ||
            (account.capabilities.planChangeRequest &&
                account.availablePlans.isNotEmpty)) ...[
          const SizedBox(height: ZynSpacing.md),
          _PlanChangeSection(account: account),
        ],
        if (account.quotas.isNotEmpty) ...[
          const SizedBox(height: ZynSpacing.lg),
          const ZynSectionHeader(
            label: 'حدود اشتراكك',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: ZynSpacing.sm),
          _QuotasCard(quotas: account.quotas),
        ],
        const SizedBox(height: ZynSpacing.lg),
        const ZynSectionHeader(
          label: 'الأجهزة',
          icon: Icons.solar_power_outlined,
        ),
        const SizedBox(height: ZynSpacing.sm),
        _DevicesCard(devices: account.devices),
        if (account.capabilities.passwordChange ||
            account.capabilities.logoutAllRefreshTokens) ...[
          const SizedBox(height: ZynSpacing.lg),
          const ZynSectionHeader(
            label: 'أمان الحساب',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: ZynSpacing.sm),
          _SecurityActionsCard(capabilities: account.capabilities),
        ],
        const SizedBox(height: ZynSpacing.lg),
        const ZynSectionHeader(
          label: 'القدرات المتاحة',
          icon: Icons.check_circle_outline_rounded,
        ),
        const SizedBox(height: ZynSpacing.sm),
        _CapabilitiesCard(capabilities: account.capabilities),
      ],
    );
  }
}

// ─── Identity hero ────────────────────────────────────────────────

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.account});

  final AccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    final name = account.fullName.isNotEmpty
        ? account.fullName
        : (account.username.isNotEmpty ? account.username : '—');
    final role = account.role.label.isNotEmpty
        ? account.role.label
        : (account.role.code.isNotEmpty
            ? AccountLabels.roleLabel(account.role.code)
            : '—');
    final initials = _initialsFrom(name);

    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.xl),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.med(),
      ),
      padding: const EdgeInsets.all(ZynSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZynColors.primary500, ZynColors.primary700],
                  ),
                  borderRadius: BorderRadius.circular(ZynRadii.xl),
                  boxShadow: [
                    BoxShadow(
                      color: ZynColors.primary500.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: ZynColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (account.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: const TextStyle(
                          color: ZynColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ZynChip(
                icon: Icons.shield_outlined,
                text: role,
                tone: ZynColors.primary500,
              ),
              ZynChip(
                icon: Icons.tag,
                text: '#${account.userId}',
                tone: ZynColors.accent,
              ),
              if (account.username.isNotEmpty)
                ZynChip(
                  icon: Icons.alternate_email_rounded,
                  text: account.username,
                  tone: ZynColors.info,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsFrom(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean == '—') return '؟';
    final parts =
        clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }
}

// ─── Subscription card ────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final AccountSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final plan = subscription.plan;
    final statusRaw = subscription.status;
    final (statusLabel, statusTone) = _statusFor(statusRaw);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ZynGradients.iconFill(statusTone),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  boxShadow: ZynShadows.iconGlow(statusTone),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.hasName ? plan.displayName() : 'باقتك الحالية',
                      style: const TextStyle(
                        color: ZynColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ZynChip(text: statusLabel, tone: statusTone),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.md),
          if (plan.price != null && plan.currency.isNotEmpty)
            _KvRow(
              label: 'السعر',
              value: '${_fmtPrice(plan.price!)} ${plan.currency}',
            ),
          if ((subscription.maxDevices ?? plan.maxDevices) != null)
            _KvRow(
              label: 'الحد الأقصى للأجهزة',
              value: '${subscription.maxDevices ?? plan.maxDevices}',
            ),
          if (subscription.expiresAt != null &&
              subscription.expiresAt!.isNotEmpty)
            _KvRow(
              label: 'تاريخ الانتهاء',
              value: formatDate(subscription.expiresAt) ?? '—',
            ),
          if (subscription.isTrial)
            _KvRow(
              label: 'نهاية الفترة التجريبية',
              value: formatDate(subscription.trialEndsAt) ?? '—',
            ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in plan.features)
                  ZynChip(
                    text: AccountLabels.planFeatureLabel(f),
                    tone: ZynColors.primary500,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static (String, Color) _statusFor(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('active')) return ('نشط', ZynColors.success);
    if (s.contains('trial')) return ('تجريبي', ZynColors.info);
    if (s.contains('expired')) return ('منتهي', ZynColors.danger);
    if (s.contains('grace')) return ('فترة سماح', ZynColors.warning);
    if (s.contains('canceled') || s.contains('cancelled')) {
      return ('ملغى', ZynColors.muted);
    }
    return (raw, ZynColors.muted);
  }

  static String _fmtPrice(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

// ─── Devices card ─────────────────────────────────────────────────

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices});

  final AccountDeviceCounts devices;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KvRow(label: 'إجمالي الأجهزة', value: '${devices.total}'),
          _KvRow(label: 'الأجهزة النشطة', value: '${devices.active}'),
          _KvRow(
            label: 'الجهاز المختار',
            value: devices.selectedDeviceId != null
                ? '#${devices.selectedDeviceId}'
                : '—',
          ),
        ],
      ),
    );
  }
}

// ─── Quotas card ──────────────────────────────────────────────────

class _QuotasCard extends StatelessWidget {
  const _QuotasCard({required this.quotas});

  final List<AccountQuota> quotas;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هذه حدود الباقة الحالية كما يحسبها الخادم. للقراءة فقط.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          for (var i = 0; i < quotas.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZynSpacing.md),
                child: Divider(color: ZynColors.lineSoft, height: 1, thickness: 1),
              ),
            _QuotaRow(quota: quotas[i]),
          ],
        ],
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.quota});

  final AccountQuota quota;

  Color get _tone {
    if (quota.isUnlimited) return ZynColors.success;
    if (!quota.isActive) return ZynColors.muted;
    final p = quota.percent;
    if (p >= 95) return ZynColors.danger;
    if (p >= 75) return ZynColors.warning;
    return ZynColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final label = quota.label.isNotEmpty ? quota.label : quota.key;
    final tone = _tone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: ZynColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
            if (!quota.isActive && quota.status.isNotEmpty)
              _QuotaStatusPill(status: quota.status),
          ],
        ),
        if (quota.description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            quota.description,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(ZynRadii.pill),
          child: LinearProgressIndicator(
            value: quota.progress,
            minHeight: 6,
            backgroundColor: ZynColors.lineSoft,
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _usedVsLimitLabel(quota),
                style: const TextStyle(
                  color: ZynColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              _remainingLabel(quota),
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (quota.sourceLabel.isNotEmpty || quota.resetPeriod.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (quota.resetPeriod.isNotEmpty)
                _QuotaMetaChip(
                  icon: Icons.refresh_outlined,
                  label: AccountLabels.quotaResetPeriodLabel(quota.resetPeriod),
                ),
              if (quota.sourceLabel.isNotEmpty)
                _QuotaMetaChip(
                  icon: Icons.info_outline,
                  label: quota.sourceLabel,
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _usedVsLimitLabel(AccountQuota q) {
    if (q.isUnlimited) return 'الاستهلاك: ${_fmt(q.used)}';
    return '${_fmt(q.used)} من ${_fmt(q.limit)}';
  }

  static String _remainingLabel(AccountQuota q) {
    if (q.isUnlimited) return 'غير محدود';
    final r = q.remaining ?? 0;
    return 'المتبقّي: ${_fmt(r)}';
  }

  static String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _QuotaStatusPill extends StatelessWidget {
  const _QuotaStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone =
        status == 'paused' ? ZynColors.warning : ZynColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        AccountLabels.quotaStatusLabel(status),
        style: TextStyle(
          color: tone,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuotaMetaChip extends StatelessWidget {
  const _QuotaMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ZynColors.surfaceAlt,
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        border: Border.all(color: ZynColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ZynColors.muted, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Security actions ────────────────────────────────────────────

class _SecurityActionsCard extends ConsumerStatefulWidget {
  const _SecurityActionsCard({required this.capabilities});

  final AccountCapabilities capabilities;

  @override
  ConsumerState<_SecurityActionsCard> createState() =>
      _SecurityActionsCardState();
}

class _SecurityActionsCardState
    extends ConsumerState<_SecurityActionsCard> {
  bool _loggingOutAll = false;

  Future<void> _confirmLogoutAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج من كل الأجهزة'),
        content: const Text(
          'سيتم إنهاء جلسة كل الأجهزة المسجَّلة بحسابك. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZynColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOutAll = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final revoked =
          await ref.read(accountRepositoryProvider).logoutAll();
      await ref.read(appSessionProvider.notifier).signOut();
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'تم تسجيل الخروج. عدد الجلسات الموقوفة: $revoked.',
          ),
        ));
      if (mounted) context.go(AppRoutes.login);
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('تعذّر تسجيل الخروج: $e')),
        );
    } finally {
      if (mounted) setState(() => _loggingOutAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = widget.capabilities;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caps.passwordChange)
            _SecurityTile(
              icon: Icons.lock_outline,
              label: 'تغيير كلمة المرور',
              subtitle: 'حدّث كلمة مرور حسابك.',
              tone: ZynColors.primary500,
              onTap: () => context.push(AppRoutes.changePassword),
            ),
          if (caps.passwordChange && caps.logoutAllRefreshTokens)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZynSpacing.sm),
              child: Divider(color: ZynColors.lineSoft, height: 1, thickness: 1),
            ),
          if (caps.logoutAllRefreshTokens)
            _SecurityTile(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج من كل الأجهزة',
              subtitle: 'إنهاء كل الجلسات المسجَّلة بحسابك.',
              tone: ZynColors.danger,
              busy: _loggingOutAll,
              onTap: _loggingOutAll ? null : _confirmLogoutAll,
            ),
        ],
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tone,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color tone;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.inner),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                ),
                child: Icon(icon, color: tone, size: 18),
              ),
              const SizedBox(width: ZynSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tone == ZynColors.danger
                            ? ZynColors.danger
                            : ZynColors.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(
                      Icons.chevron_left_rounded,
                      color: ZynColors.muted,
                      size: 22,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Capabilities card ───────────────────────────────────────────

class _CapabilitiesCard extends StatelessWidget {
  const _CapabilitiesCard({required this.capabilities});

  final AccountCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CapRow(
            label: 'تعديل الملف الشخصي',
            enabled: capabilities.profileUpdate,
          ),
          _CapRow(
            label: 'تغيير كلمة المرور',
            enabled: capabilities.passwordChange,
          ),
          _CapRow(
            label: 'تسجيل الخروج من كل الأجهزة',
            enabled: capabilities.logoutAllRefreshTokens,
          ),
          _CapRow(
            label: 'حذف الحساب',
            enabled: capabilities.accountDeletion,
          ),
          if (capabilities.mobileApiSections.isNotEmpty) ...[
            const SizedBox(height: ZynSpacing.md),
            const Text(
              'أقسام واجهة التطبيق المتاحة',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in capabilities.mobileApiSections)
                  _QuotaMetaChip(
                    icon: Icons.check_rounded,
                    label: AccountLabels.apiSectionLabel(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? ZynColors.success : ZynColors.muted;
    final icon = enabled
        ? Icons.check_circle_outline
        : Icons.remove_circle_outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            enabled ? 'متاحة' : 'غير متاحة',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan-change section + sheet ─────────────────────────────────

class _PlanChangeSection extends ConsumerStatefulWidget {
  const _PlanChangeSection({required this.account});

  final AccountSnapshot account;

  @override
  ConsumerState<_PlanChangeSection> createState() =>
      _PlanChangeSectionState();
}

class _PlanChangeSectionState extends ConsumerState<_PlanChangeSection> {
  Future<void> _openRequestSheet() async {
    final pickedPlanId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _PlanChangeRequestSheet(
          availablePlans: widget.account.availablePlans,
        ),
      ),
    );
    if (!mounted || pickedPlanId == null) return;
    final picked = widget.account.availablePlans.firstWhere(
      (p) => p.id == pickedPlanId,
      orElse: () => widget.account.availablePlans.isNotEmpty
          ? widget.account.availablePlans.first
          : AvailablePlan(
              id: pickedPlanId,
              code: '',
              nameAr: '',
              nameEn: '',
              price: 0,
              currency: 'USD',
              maxDevices: 0,
              features: const [],
              isCurrent: false,
            ),
    );
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanChangePreviewScreen(targetPlan: picked),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ref.invalidate(accountSnapshotProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.account.pendingPlanChangeRequest;
    if (pending != null) {
      return _PendingPlanChangeBanner(
        pending: pending,
        onChangeRequestedPlan: _openRequestSheet,
      );
    }
    return _RequestPlanChangeCard(onOpen: _openRequestSheet);
  }
}

class _PendingPlanChangeBanner extends StatelessWidget {
  const _PendingPlanChangeBanner({
    required this.pending,
    required this.onChangeRequestedPlan,
  });

  final PendingPlanChangeRequest pending;
  final VoidCallback onChangeRequestedPlan;

  @override
  Widget build(BuildContext context) {
    final planName = pending.requestedPlanName.isNotEmpty
        ? pending.requestedPlanName
        : '—';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ZynGradients.iconFill(ZynColors.warning),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  boxShadow: ZynShadows.iconGlow(ZynColors.warning),
                ),
                child: const Icon(
                  Icons.hourglass_top_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Text(
                  'طلب تغيير الخطة قيد المراجعة',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const ZynChip(text: 'قيد المراجعة', tone: ZynColors.warning),
            ],
          ),
          const SizedBox(height: ZynSpacing.md),
          _KvRow(label: 'الخطة المطلوبة', value: planName),
          _KvRow(
            label: 'تاريخ الطلب',
            value: _formatRequestDate(pending.createdAt) ?? '—',
          ),
          if (pending.message != null && pending.message!.isNotEmpty)
            _KvRow(label: 'الملاحظة', value: pending.message!),
          const SizedBox(height: ZynSpacing.md),
          const Text(
            'سيتواصل معك الفريق لمتابعة الطلب. لن يتم تغيير الخطة أو '
            'استلام أي مبلغ تلقائياً.',
            style: TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.65,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          ZynButton(
            label: 'اطلب خطة أخرى',
            icon: Icons.edit_outlined,
            variant: ZynButtonVariant.secondary,
            onTap: onChangeRequestedPlan,
          ),
        ],
      ),
    );
  }
}

class _RequestPlanChangeCard extends StatelessWidget {
  const _RequestPlanChangeCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                  Icons.swap_horiz_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Text(
                  'تغيير الخطة',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.sm),
          const Text(
            'اختر خطة جديدة لترى الأيام والمبالغ بدقّة. يمكنك التحويل '
            'مباشرة، أو إكمال الدفع لو كان هناك مبلغ مستحق.',
            style: TextStyle(
              color: ZynColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.65,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          ZynButton(
            label: 'غيّر خطتي',
            icon: Icons.swap_horiz,
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _PlanChangeRequestSheet extends ConsumerStatefulWidget {
  const _PlanChangeRequestSheet({required this.availablePlans});

  final List<AvailablePlan> availablePlans;

  @override
  ConsumerState<_PlanChangeRequestSheet> createState() =>
      _PlanChangeRequestSheetState();
}

class _PlanChangeRequestSheetState
    extends ConsumerState<_PlanChangeRequestSheet> {
  int? _selectedPlanId;
  String? _error;

  void _submit() {
    final selected = _selectedPlanId;
    if (selected == null) {
      setState(() => _error = 'يرجى اختيار خطة للمتابعة.');
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.availablePlans;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: ZynColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ZynRadii.hero)),
        ),
        padding: const EdgeInsets.fromLTRB(
          ZynSpacing.lg,
          ZynSpacing.md,
          ZynSpacing.lg,
          ZynSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZynColors.line,
                    borderRadius: BorderRadius.circular(ZynRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: ZynSpacing.md),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اطلب تغيير الخطة',
                      style: TextStyle(
                        color: ZynColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: ZynColors.muted),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر الخطة المطلوبة لرؤية الأيام والمبالغ الناتجة بدقّة. '
                'يمكنك بعدها تأكيد التحويل أو إكمال الدفع إن كان مستحقّاً.',
                style: TextStyle(
                  color: ZynColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: ZynSpacing.md),
              if (plans.isEmpty)
                const _SheetEmptyState()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final plan in plans)
                      _PlanRadioTile(
                        plan: plan,
                        selected: _selectedPlanId == plan.id,
                        onTap: plan.isCurrent || plan.id == null
                            ? null
                            : () => setState(() {
                                  _selectedPlanId = plan.id;
                                  _error = null;
                                }),
                      ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: ZynSpacing.sm),
                _SheetErrorBanner(message: _error!),
              ],
              const SizedBox(height: ZynSpacing.md),
              ZynButton(
                label: 'عرض تفاصيل التحويل',
                icon: Icons.arrow_forward_rounded,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRadioTile extends StatelessWidget {
  const _PlanRadioTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final AvailablePlan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final priceText = plan.price != null
        ? '${_fmtPrice(plan.price!)}${plan.currency.isNotEmpty ? ' ${plan.currency}' : ''}'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZynRadii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? ZynColors.primary50 : ZynColors.surface,
              borderRadius: BorderRadius.circular(ZynRadii.card),
              border: Border.all(
                color: selected
                    ? ZynColors.primary500.withValues(alpha: 0.45)
                    : ZynColors.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? ZynColors.primary500
                      : disabled
                          ? ZynColors.faint
                          : ZynColors.muted,
                  size: 20,
                ),
                const SizedBox(width: ZynSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.displayName(),
                              style: TextStyle(
                                color: disabled ? ZynColors.muted : ZynColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (plan.isCurrent)
                            const ZynChip(
                              text: 'خطتك الحالية',
                              tone: ZynColors.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (priceText != null)
                            _MetaChip(
                              icon: Icons.payments_outlined,
                              label: priceText,
                            ),
                          if (plan.maxDevices != null)
                            _MetaChip(
                              icon: Icons.solar_power_outlined,
                              label: 'حتى ${plan.maxDevices} جهاز',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtPrice(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: ZynColors.muted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ZynColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZynSpacing.md),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line),
      ),
      child: const Text(
        'لا توجد خطط متاحة للتغيير حالياً. تواصل مع الدعم لمزيد من '
        'المعلومات.',
        style: TextStyle(
          color: ZynColors.inkSoft,
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
      ),
    );
  }
}

class _SheetErrorBanner extends StatelessWidget {
  const _SheetErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZynColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZynRadii.inner),
        border: Border.all(color: ZynColors.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: ZynColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ZynColors.danger,
                fontSize: 12.5,
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

// ─── Atoms ────────────────────────────────────────────────────────

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

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: ZynColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: ZynColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatRequestDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final dt = DateTime.parse(iso).toLocal();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d · $hh:$mm';
  } catch (_) {
    return null;
  }
}
