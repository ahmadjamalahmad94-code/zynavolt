import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_config.dart';
import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/state/selected_device_provider.dart';
import '../../notifications/state/notifications_controller.dart';
import '../../profile/state/profile_controller.dart';

/// "More" tab — profile summary, app info, active-device hint, sign-out, and
/// a one-tap connection check. v38 adds the active-device row and the
/// /api/mobile/health probe.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _checking = false;
  bool _signingOut = false;
  bool _diagnosticsExpanded = false;
  _HealthResult? _result;

  Future<void> _signOutAndReturnToLogin() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(appSessionProvider.notifier).signOut();
      // Drop every cached user-scoped provider so a re-login (especially
      // as a different user) cannot serve the previous user's data while
      // waiting for fresh fetches. selectedDeviceProvider is included even
      // though storage was already cleared by signOut() — this resets the
      // in-memory AsyncNotifier value too.
      ref
        ..invalidate(bootstrapProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(devicesListProvider)
        ..invalidate(selectedDeviceProvider)
        ..invalidate(notificationsControllerProvider)
        ..invalidate(profileControllerProvider);
      if (!mounted) return;
      // Explicit navigation clears the go_router back-stack so Android back
      // after logout exits the app instead of replaying redirected routes.
      context.go(AppRoutes.login);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _runHealthCheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final status = await ref.read(bootstrapRepositoryProvider).health();
      if (!mounted) return;
      setState(() {
        _result = _HealthResult.ok(
          'متّصل · إصدار ${status.version.isNotEmpty ? status.version : '—'}',
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _HealthResult.fail(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _HealthResult.fail('تعذّر إكمال الفحص: $e');
      });
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final user = session.user;
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final storedDeviceId =
        ref.watch(selectedDeviceProvider).valueOrNull;
    final effectiveDeviceId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('المزيد')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // v69: explicit section header. The header sits *above* the
            // identity card so the user sees a clear "الحساب" group cue
            // before the inner card's own "الحساب" title repeats it.
            const _GroupHeader(label: 'الحساب'),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'هويتك',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    label: 'الاسم',
                    value: user?.fullName.isNotEmpty == true
                        ? user!.fullName
                        : (user?.username ?? '—'),
                  ),
                  _Row(label: 'البريد الإلكتروني', value: user?.email ?? '—'),
                  _Row(label: 'الدور', value: user?.role ?? '—'),
                  _Row(
                    label: 'الجهاز النشط',
                    value: activeDevice == null
                        ? 'لم يتم اختيار جهاز بعد'
                        : (activeDevice.name.isNotEmpty
                            ? activeDevice.name
                            : '#${activeDevice.id}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _NavTile(
              icon: Icons.person_outline,
              label: 'الملف الشخصي',
              subtitle: 'عرض وتعديل بياناتك الأساسية.',
              onTap: () => context.push(AppRoutes.profile),
            ),
            const SizedBox(height: 10),
            // v48: read-only loads list. No bottom-nav slot is free (5 tabs
            // are already populated) so loads enters via More as a tile.
            _NavTile(
              icon: Icons.bolt_outlined,
              label: 'الأحمال',
              subtitle: 'عرض الأحمال المسجَّلة على حسابك.',
              onTap: () => context.push(AppRoutes.loads),
            ),
            const SizedBox(height: 10),
            // v51: account + subscription overview (read-only).
            _NavTile(
              icon: Icons.workspace_premium_outlined,
              label: 'الحساب والاشتراك',
              subtitle: 'الباقة، الدور، حدود الأجهزة، والقدرات.',
              onTap: () => context.push(AppRoutes.account),
            ),
            const SizedBox(height: 16),
            // v69: التطبيق section — settings tile + about card.
            const _GroupHeader(label: 'التطبيق'),
            const SizedBox(height: 8),
            // v55: app settings & info (read-only).
            _NavTile(
              icon: Icons.settings_outlined,
              label: 'إعدادات التطبيق',
              subtitle: 'إصدار التطبيق، الواجهة الخلفية، اللغة، وفحص الاتصال.',
              onTap: () => context.push(AppRoutes.settings),
            ),
            const SizedBox(height: 10),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حول التطبيق',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  _Row(label: 'إصدار التطبيق', value: AppConfig.appVersion),
                  _Row(label: 'المنصة', value: AppConfig.appPlatform),
                  _Row(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // v69: التشخيص section — health check + collapsible dev info.
            const _GroupHeader(label: 'التشخيص'),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تشخيص الاتصال',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يرسل طلب GET /api/mobile/health إلى الواجهة الخلفية '
                    'دون مصادقة لتأكيد إمكانية الوصول.',
                    style: TextStyle(
                      color: AppTheme.faintMuted,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: AppTheme.formControlHeight,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _runHealthCheck,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: const Text('تحقّق من الاتصال'),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 10),
                    _ResultBanner(result: _result!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CollapsibleCard(
              title: 'تشخيص المطوّر',
              subtitle: 'حقول قراءة فقط مفيدة أثناء تجريب الاتصال بالخادم.',
              expanded: _diagnosticsExpanded,
              onToggle: () => setState(
                  () => _diagnosticsExpanded = !_diagnosticsExpanded),
              children: [
                _Row(label: 'حالة الجلسة', value: _phaseLabel(session.phase)),
                _Row(
                  label: 'الجهاز المخزَّن',
                  value: storedDeviceId != null ? '#$storedDeviceId' : '—',
                ),
                _Row(
                  label: 'الجهاز الفعّال',
                  value: effectiveDeviceId != null
                      ? '#$effectiveDeviceId'
                      : '—',
                ),
                _Row(
                  label: 'آخر خطأ تهيئة',
                  value: session.lastError?.message ?? '—',
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _signingOut ? null : _signOutAndReturnToLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              icon: _signingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}

String _phaseLabel(AppSessionPhase phase) {
  switch (phase) {
    case AppSessionPhase.unknown:
      return 'قيد الاستعادة';
    case AppSessionPhase.unauthenticated:
      return 'غير مصادَق';
    case AppSessionPhase.authenticated:
      return 'مصادَق';
  }
}

class _HealthResult {
  const _HealthResult.ok(this.message)
      : success = true;
  const _HealthResult.fail(this.message)
      : success = false;

  final bool success;
  final String message;
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final _HealthResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.success ? AppTheme.success : AppTheme.danger;
    final icon =
        result.success ? Icons.check_circle_outline : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v69: small uppercase-style section header used to group the More
/// tab into "الحساب / التطبيق / التشخيص" without crowding the layout.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, left: 4, top: 2, bottom: 0),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.faintMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
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

/// Calm collapsible card. Header is always visible (and tappable); the
/// body cross-fades and animates height when expanded. Keeps optional /
/// dev-info content out of the way without removing it.
class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null && !expanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppTheme.faintMuted,
                    size: 22,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle != null) ...[
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: AppTheme.faintMuted,
                                  fontSize: 12,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            ...children,
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: AppTheme.indigoPrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_left,
                  color: AppTheme.faintMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
