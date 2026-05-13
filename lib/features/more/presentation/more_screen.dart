import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// v100 — `url_launcher` import dropped; Battery Lab is now a
// native in-app screen, no external-browser hop. `AppConfig` is
// still imported because the About card surfaces the API base URL.

import '../../../app/app_config.dart';
import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../app/build_info.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../auth/data/auth_models.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../devices/data/devices_repository.dart';
import '../../devices/state/selected_device_provider.dart';
import '../../notifications/state/notifications_controller.dart';
import '../../profile/state/profile_controller.dart';

/// v99e — More tab redesign from scratch.
///
/// Structure (per owner brief: "عيد ترتيبه ونقحوه وعيد تصميمو من الصفر"):
///   * Hero card — gradient identity badge with avatar, name, role,
///     and an inline quick-actions row.
///   * Section: حسابي — profile, subscription, support.
///   * Section: أدواتي — Battery Lab (NEW, opens web), loads,
///     statistics, reports.
///   * Section: التطبيق — settings, about.
///   * Section: التشخيص — connection check + collapsible dev info.
///   * Logout button (full-width, danger gradient).
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

  // v100 — `_openBatteryLab` helper removed. Battery Lab is now a
  // native in-app screen reached via `context.push(AppRoutes.batteryLab)`.

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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE0E7FF),
                Color(0xFFF1F5FF),
                Color(0xFFF8FAFC),
              ],
              stops: [0.0, 0.35, 0.85],
            ),
          ),
          child: SafeArea(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _MoreHero(user: user, activeDeviceName: activeDeviceName),
            const SizedBox(height: 16),

            // ─── حسابي ──────────────────────────────────────
            const _SectionHeader(
                label: 'حسابي', icon: Icons.person_pin_rounded),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.person_outline_rounded,
              label: 'الملف الشخصي',
              subtitle: 'عرض وتعديل بياناتك الأساسية.',
              tone: AppTheme.indigoPrimary,
              onTap: () => context.push(AppRoutes.profile),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.workspace_premium_rounded,
              label: 'الحساب والاشتراك',
              subtitle: 'الباقة، الدور، حدود الأجهزة، والقدرات.',
              tone: AppTheme.violet,
              onTap: () => context.push(AppRoutes.account),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.support_agent_rounded,
              label: 'الدعم والمراسلات',
              subtitle: 'فتح تذكرة جديدة أو متابعة المحادثات الحالية.',
              tone: AppTheme.cyan,
              onTap: () => context.push(AppRoutes.support),
            ),

            const SizedBox(height: 18),
            // ─── أدواتي ─────────────────────────────────────
            const _SectionHeader(
                label: 'أدواتي', icon: Icons.dashboard_rounded),
            const SizedBox(height: 8),
            // Battery Lab — NEW. Opens the web /battery-lab page in
            // the external browser. The web view has the rich AC-IN /
            // generator / SoC / voltage diagnostics; replicating
            // them on mobile is a larger task tracked separately.
            // v100 — native Battery Lab. Was: external browser link
            // built via url_launcher. Now: push the in-app screen.
            _ActionTile(
              icon: Icons.science_rounded,
              label: 'مختبر البطارية',
              subtitle: 'تحليلات SOC، الجهد، التيار، والمدخل الخارجي.',
              tone: AppTheme.success,
              onTap: () => context.push(AppRoutes.batteryLab),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.bolt_rounded,
              label: 'الأحمال',
              subtitle: 'عرض الأحمال المسجَّلة على حسابك.',
              tone: AppTheme.warning,
              onTap: () => context.push(AppRoutes.loads),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.bar_chart_rounded,
              label: 'الإحصاءات',
              subtitle: 'ملخّصات الإنتاج والاستهلاك يومياً وشهرياً.',
              tone: AppTheme.indigoBright,
              onTap: () => context.push(AppRoutes.statistics),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.description_rounded,
              label: 'التقارير',
              subtitle: 'تقارير قابلة للتنزيل — قيد التطوير على الجوال.',
              tone: AppTheme.faintMuted,
              onTap: () => context.push(AppRoutes.reports),
            ),

            const SizedBox(height: 18),
            // ─── التطبيق ─────────────────────────────────────
            const _SectionHeader(label: 'التطبيق', icon: Icons.tune_rounded),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.settings_rounded,
              label: 'إعدادات التطبيق',
              subtitle: 'تنسيق الوقت، اللغة، فحص الاتصال، ومعلومات الإصدار.',
              tone: AppTheme.indigoPrimary,
              onTap: () => context.push(AppRoutes.settings),
            ),
            const SizedBox(height: 10),
            const _AboutCard(),

            const SizedBox(height: 18),
            // ─── التشخيص ─────────────────────────────────────
            const _SectionHeader(
                label: 'التشخيص', icon: Icons.health_and_safety_rounded),
            const SizedBox(height: 8),
            _ConnectionCheckCard(
              checking: _checking,
              result: _result,
              onCheck: _runHealthCheck,
            ),
            const SizedBox(height: 10),
            _DevInfoCard(
              expanded: _diagnosticsExpanded,
              onToggle: () => setState(
                  () => _diagnosticsExpanded = !_diagnosticsExpanded),
              sessionPhase: session.phase,
              storedDeviceId: storedDeviceId,
              effectiveDeviceId: effectiveDeviceId,
              lastError: session.lastError?.message,
            ),

            const SizedBox(height: 22),
            _LogoutButton(busy: _signingOut, onTap: _signOutAndReturnToLogin),
          ],
        ),  // ListView
          ),  // SafeArea
        ),  // DecoratedBox
      ),  // Scaffold
    );  // AnnotatedRegion
  }
}

// (v99e — legacy `overlay()` extension removed; `MoreScreen.build`
// now wires AnnotatedRegion → Scaffold → DecoratedBox → SafeArea →
// ListView directly, which reads cleaner.)

// ─── Hero ───────────────────────────────────────────────────────────────

class _MoreHero extends StatelessWidget {
  const _MoreHero({required this.user, required this.activeDeviceName});

  final AuthUser? user;
  final String? activeDeviceName;

  @override
  Widget build(BuildContext context) {
    final name = user == null
        ? '—'
        : (user!.fullName.isNotEmpty ? user!.fullName : user!.username);
    final initials = _initialsFrom(name);
    final role = user?.role ?? '—';
    final email = user?.email ?? '';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1A2E).withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF1B2C4A).withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1B2C4A),
                Color(0xFF152340),
                Color(0xFF0E1A2E),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative glow in top-right
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.45),
                        const Color(0xFF6366F1).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Top inner highlight (specular)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    // Avatar — gradient tile with initials
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF38BDF8),
                            Color(0xFF6366F1),
                            Color(0xFF4338CA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.50),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _HeroChip(
                                icon: Icons.shield_outlined,
                                text: role,
                              ),
                              if (activeDeviceName != null)
                                _HeroChip(
                                  icon: Icons.solar_power_outlined,
                                  text: activeDeviceName!,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Section header ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.indigoPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: AppTheme.indigoPrimary, size: 13),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.line.withValues(alpha: 0.8),
                    AppTheme.line.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action tile ────────────────────────────────────────────────────────

/// v99e — glossy action tile. Filled gradient icon glyph, accent
/// border, layered shadow. Matches the home screen's new card design
/// language so More feels visually continuous with Home.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tone,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  /// Optional small pill rendered next to the title — used to flag
  /// external-browser destinations like Battery Lab.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                tone.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line, width: 1),
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tone,
                        tone.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: tone.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    tone.withValues(alpha: 0.16),
                                    tone.withValues(alpha: 0.10),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: tone.withValues(alpha: 0.30),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  color: tone,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.faintMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left_rounded,
                    color: AppTheme.faintMuted.withValues(alpha: 0.75),
                    size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── About card ─────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: AppTheme.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.indigoPrimary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.indigoPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'حول التطبيق',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _KeyValue(label: 'إصدار التطبيق', value: AppConfig.appVersion),
          _KeyValue(label: 'نسخة الواجهة', value: BuildInfo.label),
          const _KeyValue(label: 'المنصة', value: AppConfig.appPlatform),
          const _KeyValue(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
        ],
      ),
    );
  }
}

// ─── Connection check ──────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: AppTheme.line, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.network_check_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تشخيص الاتصال',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'فحص الوصول للواجهة الخلفية دون مصادقة.',
                      style: TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: AppTheme.formControlHeight,
            child: FilledButton.icon(
              onPressed: checking ? null : onCheck,
              icon: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('تحقّق من الاتصال'),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            _ResultBanner(result: result!),
          ],
        ],
      ),
    );
  }
}

// ─── Dev info collapsible ──────────────────────────────────────────────

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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FBFF)],
            ),
            border: Border.all(color: AppTheme.line, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.faintMuted.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.bug_report_rounded,
                          color: AppTheme.faintMuted, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تشخيص المطوّر',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'حقول قراءة فقط مفيدة أثناء تجريب الاتصال.',
                            style: TextStyle(
                              color: AppTheme.faintMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

// ─── Logout button ─────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppTheme.danger,
                Color(0xFFB91C1C),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.danger.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.logout_rounded,
                      color: Colors.white, size: 19),
                const SizedBox(width: 10),
                const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Result banner ─────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final _HealthResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.success ? AppTheme.success : AppTheme.danger;
    final icon = result.success
        ? Icons.check_circle_outline_rounded
        : Icons.error_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
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
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────

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
                color: AppTheme.faintMuted,
                fontSize: 11.5,
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
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
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
