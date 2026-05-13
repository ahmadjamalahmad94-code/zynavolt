import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../data/account_labels.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';
import 'plan_change_preview_screen.dart';

/// Read-only Account & Subscription (v51).
///
/// Pulls GET /api/mobile/account and renders calm informational cards.
/// **No destructive / security actions:** no edit, no password change,
/// no logout-all, no delete, no billing changes. Each section is built
/// from server-declared capabilities so the UI never claims a feature
/// the backend hasn't enabled.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(accountSnapshotProvider);

    // v100 — gradient backdrop for visual continuity.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الحساب والاشتراك'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(accountSnapshotProvider),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
        child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountSnapshotProvider),
          child: snapshot.when(
            // v71: wrap loading in a ListView so RefreshIndicator always
            // has a scrollable child to drive (pull-to-refresh works
            // even during the initial load).
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل بيانات الحساب...'),
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
                          message: 'تعذّر تحميل بيانات الحساب.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(accountSnapshotProvider),
                ),
              ],
            ),
            data: (account) => _AccountBody(account: account),
          ),
        ),
        ),  // close DecoratedBox child SafeArea
      ),
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.account});
  final AccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _IdentityCard(account: account),
        const SizedBox(height: 12),
        _SubscriptionCard(subscription: account.subscription),
        // v66: plan-change request surface. Renders only when the
        // server advertises the capability OR when a pending request
        // is already on file — keeps the screen calm for older
        // backends that don't ship the new keys.
        if (account.pendingPlanChangeRequest != null ||
            (account.capabilities.planChangeRequest &&
                account.availablePlans.isNotEmpty)) ...[
          const SizedBox(height: 12),
          _PlanChangeSection(account: account),
        ],
        // v76: subscriber quota visibility. Read-only — shows
        // limit / used / remaining for each active tenant quota.
        // Hidden when the server returned no rows (e.g. no tenant
        // yet, or no active quotas), so older backends without the
        // `quotas` key stay calm.
        if (account.quotas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _QuotasCard(quotas: account.quotas),
        ],
        const SizedBox(height: 12),
        _DevicesCard(devices: account.devices),
        // v89: real account actions (change password + logout-all), gated
        // on server-declared capabilities. The previous v76 read-only
        // banner is gone because the screen now offers real actions.
        if (account.capabilities.passwordChange ||
            account.capabilities.logoutAllRefreshTokens) ...[
          const SizedBox(height: 12),
          _SecurityActionsCard(capabilities: account.capabilities),
        ],
        const SizedBox(height: 12),
        _CapabilitiesCard(capabilities: account.capabilities),
        const SizedBox(height: 24),
      ],
    );
  }
}

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
          'سيتم إنهاء جلسة كل الأجهزة المسجَّلة بحسابك. '
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
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
      // After revoking refresh tokens, sign out locally so the next
      // 401 doesn't surprise the user — the access token will expire
      // on its own; signing out clears it deterministically.
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
      // Router redirect picks up the unauthenticated phase and sends
      // the user back to /login; the explicit navigation here clears
      // the stack so back-button doesn't return to /account.
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
    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'أمان الحساب'),
          const SizedBox(height: 8),
          if (caps.passwordChange)
            _ActionTile(
              icon: Icons.lock_outline,
              label: 'تغيير كلمة المرور',
              subtitle: 'حدّث كلمة مرور حسابك.',
              onTap: () => context.push(AppRoutes.changePassword),
            ),
          if (caps.passwordChange && caps.logoutAllRefreshTokens)
            const Divider(color: AppTheme.line, height: 12, thickness: 1),
          if (caps.logoutAllRefreshTokens)
            _ActionTile(
              icon: Icons.logout,
              label: 'تسجيل الخروج من كل الأجهزة',
              subtitle: 'إنهاء كل الجلسات المسجَّلة بحسابك.',
              tone: AppTheme.danger,
              busy: _loggingOutAll,
              onTap: _loggingOutAll ? null : _confirmLogoutAll,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.tone = AppTheme.indigoPrimary,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Color tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: tone, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: tone == AppTheme.danger
                            ? AppTheme.danger
                            : AppTheme.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
                  : Icon(Icons.chevron_left,
                      color: AppTheme.faintMuted,
                      size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.account});
  final AccountSnapshot account;

  @override
  Widget build(BuildContext context) {
    final name = account.fullName.isNotEmpty
        ? account.fullName
        : (account.username.isNotEmpty ? account.username : '—');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الهوية'),
          const SizedBox(height: 8),
          _KvRow(label: 'الاسم', value: name),
          _KvRow(
            label: 'اسم المستخدم',
            value: account.username.isNotEmpty ? account.username : '—',
          ),
          _KvRow(
            label: 'البريد الإلكتروني',
            value: account.email.isNotEmpty ? account.email : '—',
          ),
          _KvRow(
            label: 'الدور',
            // v57: prefer server-translated label; if absent, map the role
            // code to its Arabic label rather than showing the raw slug.
            value: account.role.label.isNotEmpty
                ? account.role.label
                : (account.role.code.isNotEmpty
                    ? AccountLabels.roleLabel(account.role.code)
                    : '—'),
          ),
          _KvRow(label: 'المعرّف', value: '#${account.userId}'),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});
  final AccountSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final plan = subscription.plan;
    return AppCard(
      // v67: subscription is the most actionable info on this screen,
      // so it gets the elevated treatment to stand out among the calmer
      // identity / devices / capabilities cards.
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الاشتراك'),
          const SizedBox(height: 8),
          _KvRow(
            label: 'الحالة',
            value: subscription.status.isNotEmpty
                ? _statusLabel(subscription.status)
                : '—',
          ),
          if (plan.hasName)
            _KvRow(
              label: 'الباقة',
              value: plan.displayName(),
            ),
          if (plan.price != null && plan.currency.isNotEmpty)
            _KvRow(
              label: 'السعر',
              value: '${_fmtPrice(plan.price!)} ${plan.currency}',
            ),
          if ((subscription.maxDevices ?? plan.maxDevices) != null)
            _KvRow(
              label: 'الحد الأقصى للأجهزة',
              value:
                  '${subscription.maxDevices ?? plan.maxDevices}',
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in plan.features)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.indigoSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.indigoBright.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      // v57: convert raw `can_*` slugs into Arabic labels.
                      AccountLabels.planFeatureLabel(f),
                      style: const TextStyle(
                        color: AppTheme.indigoPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('active')) return 'نشط';
    if (s.contains('trial')) return 'تجريبي';
    if (s.contains('expired')) return 'منتهي';
    if (s.contains('grace')) return 'فترة سماح';
    if (s.contains('canceled') || s.contains('cancelled')) return 'ملغى';
    return raw;
  }

  static String _fmtPrice(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices});
  final AccountDeviceCounts devices;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الأجهزة'),
          const SizedBox(height: 8),
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

/// v76: subscriber-visible quotas card.
///
/// Renders one row per `AccountQuota`: Arabic label, calm description
/// when present, a soft progress bar, "X من Y" used/limit, and a
/// remaining/unlimited badge. Status (`inactive` / `paused`) surfaces
/// as a quiet pill so the user knows when a quota isn't enforced.
///
/// All values come from `quota_summary_rows` via the v76 backend
/// projection — no quota math happens here. The card never claims a
/// capability ("upgrade now", "buy more") — it's informational only,
/// matching the v76 brief's "calm, read-only" tone.
class _QuotasCard extends StatelessWidget {
  const _QuotasCard({required this.quotas});
  final List<AccountQuota> quotas;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'حدود اشتراكك'),
          const SizedBox(height: 4),
          const Text(
            'هذه حدود الباقة الحالية كما يحسبها الخادم. للقراءة فقط.',
            style: TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < quotas.length; i++) ...[
            if (i > 0)
              const Divider(color: AppTheme.line, height: 16, thickness: 1),
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

  /// Soft tone for the progress bar — calm green when there's headroom,
  /// amber once usage crosses 75%, red past 95%. Unlimited quotas read
  /// as calm green because the bar is at 0.
  Color get _tone {
    if (quota.isUnlimited) return AppTheme.success;
    if (!quota.isActive) return AppTheme.faintMuted;
    final p = quota.percent;
    if (p >= 95) return AppTheme.danger;
    if (p >= 75) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    final label = quota.label.isNotEmpty ? quota.label : quota.key;
    final tone = _tone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row: label + status pill (only when not active).
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
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
              color: AppTheme.faintMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Soft progress bar — unlimited quotas show a near-empty bar
        // with a calm green tone so it never reads as "almost full".
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: quota.progress,
            minHeight: 6,
            backgroundColor: AppTheme.line,
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
        const SizedBox(height: 6),
        // Numbers row: "X من Y" used/limit + remaining/unlimited badge.
        Row(
          children: [
            Expanded(
              child: Text(
                _usedVsLimitLabel(quota),
                style: const TextStyle(
                  color: AppTheme.softInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _remainingLabel(quota),
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        // Source / reset period footer — quiet metadata so the user
        // can see *why* the limit is what it is and when it resets.
        if (quota.sourceLabel.isNotEmpty || quota.resetPeriod.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (quota.resetPeriod.isNotEmpty)
                _QuotaMetaChip(
                  icon: Icons.refresh_outlined,
                  label: AccountLabels.quotaResetPeriodLabel(
                    quota.resetPeriod,
                  ),
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
    final tone = status == 'paused' ? AppTheme.warning : AppTheme.faintMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        AccountLabels.quotaStatusLabel(status),
        style: TextStyle(
          color: tone,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
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
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.faintMuted, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilitiesCard extends StatelessWidget {
  const _CapabilitiesCard({required this.capabilities});
  final AccountCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'القدرات المتاحة'),
          const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            const Text(
              'أقسام واجهة التطبيق المتاحة',
              style: TextStyle(
                color: AppTheme.muted,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.softBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Text(
                      // v57: convert raw section slugs into Arabic labels.
                      AccountLabels.apiSectionLabel(s),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
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
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
    final color = enabled ? AppTheme.success : AppTheme.faintMuted;
    final icon = enabled
        ? Icons.check_circle_outline
        : Icons.remove_circle_outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
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

// ─── v66: plan-change request section + modal sheet ──────────────────

/// Renders one of two states:
///   * pending request banner — when `account.pendingPlanChangeRequest`
///     is set. Calm, honest copy ("قيد المراجعة من الفريق").
///   * request-change action — when no pending request AND the server
///     advertises `capabilities.plan_change_request`.
///
/// Both states deep-link to the same modal sheet for transparency
/// (the pending banner offers an "اطلب خطة أخرى" button which replaces
/// the open case — same cancel-then-create semantics the backend uses).
class _PlanChangeSection extends ConsumerStatefulWidget {
  const _PlanChangeSection({required this.account});
  final AccountSnapshot account;

  @override
  ConsumerState<_PlanChangeSection> createState() =>
      _PlanChangeSectionState();
}

class _PlanChangeSectionState extends ConsumerState<_PlanChangeSection> {
  /// v91 — replaces the v66 "send a request to admin" flow with the
  /// v87 subscriber-driven flow: pick a plan via the existing sheet,
  /// then navigate to `PlanChangePreviewScreen` which computes both
  /// scenarios, lets the subscriber confirm, and (for upgrade
  /// keep-days) launches the Stripe-hosted checkout. The plan
  /// switches immediately without admin approval; admins only see
  /// it in the workbench when payment is involved.
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
          currentPlanId: widget.account.subscription.plan.id,
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
      // The preview screen popped with `true` on a successful
      // apply / checkout launch — refresh the account snapshot so
      // the new plan / pending invoice appears.
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.hourglass_top_outlined,
                  color: AppTheme.indigoPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'طلب تغيير الخطة قيد المراجعة',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Calm status pill — never claims "approved" / "paid".
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.30),
                  ),
                ),
                child: const Text(
                  'قيد المراجعة',
                  style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KvRow(label: 'الخطة المطلوبة', value: planName),
          _KvRow(
            label: 'تاريخ الطلب',
            value: _formatRequestDate(pending.createdAt) ?? '—',
          ),
          if (pending.message != null && pending.message!.isNotEmpty)
            _KvRow(label: 'الملاحظة', value: pending.message!),
          const SizedBox(height: 10),
          const Text(
            'سيتواصل معك الفريق لمتابعة الطلب. لن يتم تغيير الخطة أو '
            'استلام أي مبلغ تلقائياً.',
            style: TextStyle(
              color: AppTheme.softInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppTheme.formControlHeight,
            child: OutlinedButton.icon(
              onPressed: onChangeRequestedPlan,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('اطلب خطة أخرى'),
            ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.swap_horiz_outlined,
                  color: AppTheme.indigoPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تغيير الخطة',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'اختر خطة جديدة لترى الأيام والمبالغ بدقّة. '
            'يمكنك التحويل مباشرة، أو إكمال الدفع لو كان هناك مبلغ مستحق.',
            style: TextStyle(
              color: AppTheme.softInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppTheme.formControlHeight,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('غيّر خطتي'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet — lists available plans (current plan dimmed and
/// non-selectable), captures an optional message, submits via the v65
/// endpoint. Pops with `true` on success so the parent can refresh.
class _PlanChangeRequestSheet extends ConsumerStatefulWidget {
  const _PlanChangeRequestSheet({
    required this.availablePlans,
    required this.currentPlanId,
  });

  final List<AvailablePlan> availablePlans;
  final int? currentPlanId;

  @override
  ConsumerState<_PlanChangeRequestSheet> createState() =>
      _PlanChangeRequestSheetState();
}

class _PlanChangeRequestSheetState
    extends ConsumerState<_PlanChangeRequestSheet> {
  int? _selectedPlanId;
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  /// v91 — picker only. Returns the chosen plan id to the parent;
  /// the parent navigates to `PlanChangePreviewScreen` for the full
  /// preview/confirm/checkout flow. The legacy "send a request to
  /// admin" path (v66) is intentionally removed from this sheet —
  /// the new flow applies the plan immediately (or routes to
  /// Stripe for the upgrade-keep-days case).
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
    // Selectable rows = plans the user can actually request. We keep
    // the current plan visible (dimmed) so the user gets a calm "this
    // is your current plan" cue rather than an inexplicable absence.
    final plans = widget.availablePlans;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.softBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اطلب تغيير الخطة',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                  color: AppTheme.faintMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              TextField(
                controller: _messageCtrl,
                maxLines: 3,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة قصيرة (اختياري)',
                  hintText: 'مثال: أرغب بترقية الخطة لزيادة عدد الأجهزة.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _SheetErrorBanner(message: _error!),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: AppTheme.formControlHeight + 4,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('عرض تفاصيل التحويل'),
                ),
              ),
              const SizedBox(height: 6),
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
    final Color tone = selected
        ? AppTheme.indigoPrimary
        : disabled
            ? AppTheme.faintMuted
            : AppTheme.muted;
    final priceText = (plan.price != null)
        ? '${_fmtPrice(plan.price!)}${plan.currency.isNotEmpty ? ' ${plan.currency}' : ''}'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.indigoSoft : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: selected
                    ? AppTheme.indigoBright.withValues(alpha: 0.40)
                    : AppTheme.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: tone,
                  size: 20,
                ),
                const SizedBox(width: 10),
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
                                color: disabled
                                    ? AppTheme.faintMuted
                                    : AppTheme.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (plan.isCurrent)
                            const _CurrentPlanPill(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
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

class _CurrentPlanPill extends StatelessWidget {
  const _CurrentPlanPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.30)),
      ),
      child: const Text(
        'خطتك الحالية',
        style: TextStyle(
          color: AppTheme.success,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
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
        Icon(icon, color: AppTheme.faintMuted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.faintMuted,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Text(
        'لا توجد خطط متاحة للتغيير حالياً. تواصل مع الدعم لمزيد من '
        'المعلومات.',
        style: TextStyle(
          color: AppTheme.softInk,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
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
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.danger,
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

/// Parse the backend `created_at` ISO string into a friendly Arabic
/// date for the pending-request banner. Returns `null` for malformed
/// values so the caller can fall back to `'—'`.
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
