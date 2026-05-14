import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_config.dart';
import '../../../app/app_router.dart';
import '../../../app/build_info.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/app_session.dart';
import '../../auth/data/auth_models.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/state/selected_device_provider.dart';
import '../../notifications/state/notifications_controller.dart';
import '../../profile/state/profile_controller.dart';

/// v102 DS v1 — More tab (control center).
///
/// Full rebuild on the Modern Mobile SaaS Energy DS. Structure:
///
///   1. Profile hero (navy gradient) — avatar, name, email, role
///      chip + active-device chip + edit button.
///   2. 2×4 tools grid — eight icon tiles, each a destination for
///      an account/diagnostic/data sub-section.
///   3. Diagnostics card — health check + collapsible dev info.
///   4. About card — version, build label, platform, API base.
///   5. Logout button (danger).
///
/// Battery Lab is explicitly out-of-v102 rebuild scope; the tile
/// still pushes [AppRoutes.batteryLab] which renders the existing
/// dark-themed lab screen.
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
      ref
        ..invalidate(bootstrapProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(devicesListProvider)
        ..invalidate(selectedDeviceProvider)
        ..invalidate(notificationsControllerProvider)
        ..invalidate(profileControllerProvider);
      if (!mounted) return;
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
      setState(() => _result = _HealthResult.fail(e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = _HealthResult.fail('تعذّر إكمال الفحص: $e'));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final user = session.user;
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final storedDeviceId = ref.watch(selectedDeviceProvider).valueOrNull;
    final effectiveDeviceId = ref.watch(effectiveDeviceIdProvider);

    final activeDeviceName = activeDevice == null
        ? null
        : (activeDevice.name.isNotEmpty
            ? activeDevice.name
            : '#${activeDevice.id}');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ZynScreen(
        hero: const ZynPageHero(
          title: 'حسابي',
          subtitle: 'البروفايل والاشتراك والإعدادات والدعم.',
          showBackButton: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileSummaryCard(
              user: user,
              activeDeviceName: activeDeviceName,
              onEditTap: () => context.push(AppRoutes.profile),
            ),
            const SizedBox(height: ZynSpacing.lg),
            const ZynSectionHeader(
              label: 'أدواتي',
              icon: Icons.apps_rounded,
            ),
            const SizedBox(height: ZynSpacing.sm),
            _ToolsGrid(onTap: (route) => context.push(route)),
            const SizedBox(height: ZynSpacing.lg),
            const ZynSectionHeader(
              label: 'التشخيص',
              icon: Icons.health_and_safety_rounded,
            ),
            const SizedBox(height: ZynSpacing.sm),
            _ConnectionCheckCard(
              checking: _checking,
              result: _result,
              onCheck: _runHealthCheck,
            ),
            const SizedBox(height: ZynSpacing.sm),
            _DevInfoCard(
              expanded: _diagnosticsExpanded,
              onToggle: () => setState(
                () => _diagnosticsExpanded = !_diagnosticsExpanded,
              ),
              sessionPhase: session.phase,
              storedDeviceId: storedDeviceId,
              effectiveDeviceId: effectiveDeviceId,
              lastError: session.lastError?.message,
            ),
            const SizedBox(height: ZynSpacing.lg),
            const ZynSectionHeader(
              label: 'حول التطبيق',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: ZynSpacing.sm),
            const _AboutCard(),
            const SizedBox(height: ZynSpacing.xl),
            ZynButton(
              label: 'تسجيل الخروج',
              icon: Icons.logout_rounded,
              variant: ZynButtonVariant.danger,
              busy: _signingOut,
              onTap: _signOutAndReturnToLogin,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile summary card (sits below the hero) ─────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.user,
    required this.activeDeviceName,
    required this.onEditTap,
  });

  final AuthUser? user;
  final String? activeDeviceName;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final name = user == null
        ? '—'
        : (user!.fullName.isNotEmpty ? user!.fullName : user!.username);
    final initials = _initialsFrom(name);
    final role = user?.role ?? '—';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.xl),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.med(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initials: initials),
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
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
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
              _EditButton(onTap: onEditTap),
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
              if (activeDeviceName != null)
                ZynChip(
                  icon: Icons.solar_power_outlined,
                  text: activeDeviceName!,
                  tone: ZynColors.success,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsFrom(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean == '—') return '?';
    final parts =
        clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.characters.take(2).toString();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ZynColors.primary500.withValues(alpha: 0.45),
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ZynColors.primary50,
            shape: BoxShape.circle,
            border: Border.all(
              color: ZynColors.primary500.withValues(alpha: 0.30),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.edit_outlined,
            color: ZynColors.primary700,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─── Tools grid (2×4) ───────────────────────────────────────────────

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = <_ToolItem>[
    _ToolItem(
      icon: Icons.person_outline_rounded,
      label: 'الملف الشخصي',
      route: AppRoutes.profile,
      tone: ZynColors.primary500,
    ),
    _ToolItem(
      icon: Icons.workspace_premium_rounded,
      label: 'الحساب والاشتراك',
      route: AppRoutes.account,
      tone: ZynColors.accent,
    ),
    _ToolItem(
      icon: Icons.support_agent_rounded,
      label: 'الدعم والمراسلات',
      route: AppRoutes.support,
      tone: ZynColors.info,
    ),
    _ToolItem(
      icon: Icons.bolt_rounded,
      label: 'الأحمال',
      route: AppRoutes.loads,
      tone: ZynColors.warning,
    ),
    _ToolItem(
      icon: Icons.bar_chart_rounded,
      label: 'الإحصاءات',
      route: AppRoutes.statistics,
      tone: ZynColors.primary700,
    ),
    _ToolItem(
      icon: Icons.description_outlined,
      label: 'التقارير',
      route: AppRoutes.reports,
      tone: ZynColors.muted,
    ),
    _ToolItem(
      icon: Icons.science_outlined,
      label: 'مختبر البطارية',
      route: AppRoutes.batteryLab,
      tone: ZynColors.success,
    ),
    _ToolItem(
      icon: Icons.settings_outlined,
      label: 'إعدادات التطبيق',
      route: AppRoutes.settings,
      tone: ZynColors.inkSoft,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: ZynSpacing.md,
        crossAxisSpacing: ZynSpacing.md,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, i) {
        final it = _items[i];
        return _ToolTile(item: it, onTap: () => onTap(it.route));
      },
    );
  }
}

class _ToolItem {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color tone;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.item, required this.onTap});

  final _ToolItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(color: ZynColors.line, width: 1),
            boxShadow: ZynShadows.soft(tint: item.tone),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZynSpacing.md,
              ZynSpacing.md,
              ZynSpacing.md,
              ZynSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ZynGradients.iconFill(item.tone),
                    borderRadius: BorderRadius.circular(ZynRadii.inner),
                    boxShadow: ZynShadows.iconGlow(item.tone),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: ZynSpacing.sm),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Connection check ──────────────────────────────────────────────

class _ConnectionCheckCard extends StatelessWidget {
  const _ConnectionCheckCard({
    required this.checking,
    required this.result,
    required this.onCheck,
  });

  final bool checking;
  final _HealthResult? result;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ZynGradients.iconFill(ZynColors.success),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  boxShadow: ZynShadows.iconGlow(ZynColors.success),
                ),
                child: const Icon(
                  Icons.network_check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تشخيص الاتصال',
                      style: TextStyle(
                        color: ZynColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'فحص الوصول للواجهة الخلفية دون مصادقة.',
                      style: TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.md),
          ZynButton(
            label: 'تحقّق من الاتصال',
            icon: Icons.bolt_rounded,
            busy: checking,
            onTap: onCheck,
          ),
          if (result != null) ...[
            const SizedBox(height: ZynSpacing.sm),
            _ResultBanner(result: result!),
          ],
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final _HealthResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.success ? ZynColors.success : ZynColors.danger;
    final icon = result.success
        ? Icons.check_circle_outline_rounded
        : Icons.error_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZynRadii.inner),
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

// ─── Dev info ─────────────────────────────────────────────────────

class _DevInfoCard extends StatelessWidget {
  const _DevInfoCard({
    required this.expanded,
    required this.onToggle,
    required this.sessionPhase,
    required this.storedDeviceId,
    required this.effectiveDeviceId,
    required this.lastError,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final AppSessionPhase sessionPhase;
  final int? storedDeviceId;
  final int? effectiveDeviceId;
  final String? lastError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(color: ZynColors.line, width: 1),
            boxShadow: ZynShadows.soft(),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZynSpacing.lg,
              ZynSpacing.md,
              ZynSpacing.lg,
              ZynSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ZynColors.muted.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(ZynRadii.inner),
                      ),
                      child: const Icon(
                        Icons.bug_report_rounded,
                        color: ZynColors.muted,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: ZynSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تشخيص المطوّر',
                            style: TextStyle(
                              color: ZynColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'حقول قراءة فقط مفيدة أثناء تجريب الاتصال.',
                            style: TextStyle(
                              color: ZynColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ZynColors.muted,
                      size: 22,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: ZynSpacing.md),
                          child: Column(
                            children: [
                              _KeyValue(
                                label: 'حالة الجلسة',
                                value: _phaseLabel(sessionPhase),
                              ),
                              _KeyValue(
                                label: 'الجهاز المخزَّن',
                                value: storedDeviceId != null
                                    ? '#$storedDeviceId'
                                    : '—',
                              ),
                              _KeyValue(
                                label: 'الجهاز الفعّال',
                                value: effectiveDeviceId != null
                                    ? '#$effectiveDeviceId'
                                    : '—',
                              ),
                              _KeyValue(
                                label: 'آخر خطأ تهيئة',
                                value: lastError ?? '—',
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── About card ───────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.md,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValue(label: 'إصدار التطبيق', value: AppConfig.appVersion),
          _KeyValue(label: 'وسم الإصدار', value: BuildInfo.label),
          _KeyValue(label: 'المنصة', value: AppConfig.appPlatform),
          _KeyValue(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

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
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
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
  const _HealthResult.ok(this.message) : success = true;
  const _HealthResult.fail(this.message) : success = false;

  final bool success;
  final String message;
}
