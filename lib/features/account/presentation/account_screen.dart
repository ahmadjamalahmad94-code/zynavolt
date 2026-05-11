import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/utils/timestamp.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/read_only_notice.dart';
import '../data/account_labels.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الحساب والاشتراك'),
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(accountSnapshotProvider),
          ),
        ],
      ),
      body: SafeArea(
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
        // v76: explicit "view only" banner — the account screen has no
        // edit / cancel / change-plan actions and users deserve to know
        // that upfront, before they scroll looking for one.
        const ReadOnlyNotice(
          message: 'بيانات الحساب والاشتراك معروضة هنا للعرض فقط حالياً.',
        ),
        const SizedBox(height: 12),
        _IdentityCard(account: account),
        const SizedBox(height: 12),
        _SubscriptionCard(subscription: account.subscription),
        const SizedBox(height: 12),
        _DevicesCard(devices: account.devices),
        const SizedBox(height: 12),
        _CapabilitiesCard(capabilities: account.capabilities),
        const SizedBox(height: 24),
      ],
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
