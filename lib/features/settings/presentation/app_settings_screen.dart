import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_config.dart';
import '../../../app/build_info.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/time_format_provider.dart';
import '../../../core/utils/backend_time.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../devices/state/selected_device_provider.dart';

/// v102 DS v1 — إعدادات التطبيق.
///
/// Read-only app & environment metadata + safe pointers (active
/// device, time-format pref, connection health). No language
/// switching, no server-URL override, no secrets.
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _checking = false;
  String? _checkMessage;
  bool _checkSuccess = false;

  Future<void> _runHealthCheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _checkMessage = null;
    });
    try {
      final status = await ref.read(bootstrapRepositoryProvider).health();
      if (!mounted) return;
      setState(() {
        _checkSuccess = true;
        _checkMessage =
            'متّصل · إصدار ${status.version.isNotEmpty ? status.version : '—'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkSuccess = false;
        _checkMessage = 'تعذّر إكمال الفحص: $e';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return ZynScreen(
      hero: const ZynPageHero(
        title: 'إعدادات التطبيق',
        subtitle: 'تخصيص التطبيق ومعلومات الإصدار والاتصال.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandCard(),
          const SizedBox(height: ZynSpacing.md),
          const _AppInfoCard(),
          const SizedBox(height: ZynSpacing.md),
          _ConnectionCard(
            checking: _checking,
            message: _checkMessage,
            success: _checkSuccess,
            onCheck: _runHealthCheck,
          ),
          const SizedBox(height: ZynSpacing.md),
          _ActiveDeviceCard(
            deviceName: activeDevice?.name ?? '',
            deviceId: activeId,
            status: activeDevice?.connectionStatus ?? '',
          ),
          const SizedBox(height: ZynSpacing.md),
          const _TimeFormatCard(),
          const SizedBox(height: ZynSpacing.md),
          const _LanguageCard(),
        ],
      ),
    );
  }
}

// ─── Brand card ─────────────────────────────────────────────────

class _BrandCard extends StatelessWidget {
  const _BrandCard();

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
        gradient: ZynGradients.glossSurface(tint: ZynColors.primary500),
        borderRadius: BorderRadius.circular(ZynRadii.xl),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.med(),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ZynRadii.inner),
            child: Image.asset(
              'assets/branding/zynavolt_logo.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ZynGradients.iconFill(ZynColors.primary500),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zynavolt',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'منصة إدارة الطاقة الشمسية',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

// ─── App info ──────────────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label: 'حول التطبيق'),
          SizedBox(height: ZynSpacing.sm),
          _KvRow(label: 'إصدار التطبيق', value: AppConfig.appVersion),
          _KvRow(label: 'وسم الإصدار', value: BuildInfo.label),
          _KvRow(label: 'المنصة', value: AppConfig.appPlatform),
          _KvRow(label: 'لغة الواجهة الافتراضية', value: AppConfig.defaultLocale),
          _KvRow(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
        ],
      ),
    );
  }
}

// ─── Connection check ───────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.checking,
    required this.message,
    required this.success,
    required this.onCheck,
  });

  final bool checking;
  final String? message;
  final bool success;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الاتصال بالخادم'),
          const SizedBox(height: 6),
          const Text(
            'يرسل طلب GET /api/mobile/health بدون مصادقة لتأكيد إمكانية الوصول.',
            style: TextStyle(
              color: ZynColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const SizedBox(height: ZynSpacing.md),
          ZynButton(
            label: 'تحقّق من الاتصال',
            icon: Icons.network_check_rounded,
            busy: checking,
            onTap: onCheck,
          ),
          if (message != null) ...[
            const SizedBox(height: ZynSpacing.sm),
            _ResultBanner(message: message!, success: success),
          ],
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? ZynColors.success : ZynColors.danger;
    final icon = success
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
              message,
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

// ─── Active device ─────────────────────────────────────────────

class _ActiveDeviceCard extends StatelessWidget {
  const _ActiveDeviceCard({
    required this.deviceName,
    required this.deviceId,
    required this.status,
  });

  final String deviceName;
  final int? deviceId;
  final String status;

  @override
  Widget build(BuildContext context) {
    final hasDevice = deviceId != null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الجهاز النشط'),
          const SizedBox(height: ZynSpacing.sm),
          if (!hasDevice)
            const Text(
              'لم يتم اختيار جهاز نشط بعد. اختر جهازاً من تبويب "الأجهزة".',
              style: TextStyle(
                color: ZynColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            )
          else ...[
            _KvRow(
              label: 'الاسم',
              value: deviceName.isNotEmpty ? deviceName : '—',
            ),
            _KvRow(label: 'المعرّف', value: '#$deviceId'),
            _KvRow(
              label: 'حالة الاتصال',
              value: status.isNotEmpty ? status : '—',
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Time format ───────────────────────────────────────────────

class _TimeFormatCard extends ConsumerWidget {
  const _TimeFormatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(timeFormatPrefProvider);
    final controller = ref.read(timeFormatPrefProvider.notifier);
    return _Card(
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
                  gradient: ZynGradients.iconFill(ZynColors.primary500),
                  borderRadius: BorderRadius.circular(ZynRadii.inner),
                  boxShadow: ZynShadows.iconGlow(ZynColors.primary500),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تنسيق الوقت',
                      style: TextStyle(
                        color: ZynColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'كيف تظهر أوقات القراءات والإشعارات في التطبيق.',
                      style: TextStyle(
                        color: ZynColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZynSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TimeFormatOption(
                  active: pref == TimeFormatPref.h12,
                  title: '12 ساعة',
                  sample: '06:30 ص',
                  onTap: () => controller.setPref(TimeFormatPref.h12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeFormatOption(
                  active: pref == TimeFormatPref.h24,
                  title: '24 ساعة',
                  sample: '18:30',
                  onTap: () => controller.setPref(TimeFormatPref.h24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeFormatOption extends StatelessWidget {
  const _TimeFormatOption({
    required this.active,
    required this.title,
    required this.sample,
    required this.onTap,
  });

  final bool active;
  final String title;
  final String sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.tile),
        child: Ink(
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZynColors.primary500, ZynColors.primary700],
                  )
                : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(ZynRadii.tile),
            border: Border.all(
              color: active ? ZynColors.primary700 : ZynColors.line,
              width: 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ZynColors.primary500.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.white : ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sample,
                  style: TextStyle(
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : ZynColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

// ─── Language ──────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'اللغة'),
          const SizedBox(height: ZynSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ZynColors.primary50,
                  borderRadius: BorderRadius.circular(ZynRadii.tight),
                ),
                child: const Icon(
                  Icons.translate_outlined,
                  color: ZynColors.primary700,
                  size: 16,
                ),
              ),
              const SizedBox(width: ZynSpacing.md),
              const Expanded(
                child: Text(
                  'الواجهة متاحة حالياً بالعربية فقط. '
                  'ستضاف لغات إضافية لاحقاً بعد اكتمال إعداد الترجمة.',
                  style: TextStyle(
                    color: ZynColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Atoms ────────────────────────────────────────────────────

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: ZynColors.ink,
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
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
