import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_config.dart';
import '../../../app/app_theme.dart';
import '../../../app/build_info.dart';
import '../../../core/state/time_format_provider.dart';
import '../../../core/utils/backend_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../devices/state/selected_device_provider.dart';

/// Read-only app settings / info (v55).
///
/// Surfaces the public app & environment metadata, plus a couple of safe
/// pointers (active device summary, language readiness note). No editing,
/// no language switching, no server-URL override, no secrets.
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
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDevice = ref.watch(effectiveDeviceProvider);
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('إعدادات التطبيق')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BrandCard(),
            const SizedBox(height: 12),
            _AppInfoCard(),
            const SizedBox(height: 12),
            _ConnectionCard(
              checking: _checking,
              message: _checkMessage,
              success: _checkSuccess,
              onCheck: _runHealthCheck,
            ),
            const SizedBox(height: 12),
            _ActiveDeviceCard(
              deviceName: activeDevice?.name ?? '',
              deviceId: activeId,
              status: activeDevice?.connectionStatus ?? '',
            ),
            const SizedBox(height: 12),
            const _TimeFormatCard(),
            const SizedBox(height: 12),
            const _LanguageCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// v99d — Settings card that lets the user toggle between 12-hour
/// (h:mm ص/م) and 24-hour (HH:mm) time everywhere in the app. The
/// preference is persisted via `timeFormatPrefProvider` and read on
/// app boot so the choice survives a restart.
class _TimeFormatCard extends ConsumerWidget {
  const _TimeFormatCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(timeFormatPrefProvider);
    final controller = ref.read(timeFormatPrefProvider.notifier);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.indigoPrimary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تنسيق الوقت',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'كيف تظهر أوقات القراءات والإشعارات في التطبيق.',
                      style: TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Two pill-buttons inline. Active option carries the
          // indigo gradient; the other stays neutral.
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                  )
                : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppTheme.indigoPrimary
                  : AppTheme.line,
              width: 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.indigoPrimary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.white : AppTheme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sample,
                  style: TextStyle(
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.faintMuted,
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

class _BrandCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // v70: brand card is the screen's hero — uses the v58 design-system
    // softShadow via `elevated: true` so it stands out above the calmer
    // info / connection / device / language cards.
    return AppCard(
      elevated: true,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: AppTheme.indigoPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zynavolt',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'منصة إدارة الطاقة الشمسية',
                  style: TextStyle(
                    color: AppTheme.faintMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _AppInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle(label: 'حول التطبيق'),
          SizedBox(height: 8),
          _KvRow(label: 'إصدار التطبيق', value: AppConfig.appVersion),
          _KvRow(label: 'نسخة الواجهة', value: BuildInfo.label),
          _KvRow(label: 'المنصة', value: AppConfig.appPlatform),
          _KvRow(label: 'لغة الواجهة الافتراضية', value: AppConfig.defaultLocale),
          _KvRow(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
        ],
      ),
    );
  }
}

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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الاتصال بالخادم'),
          const SizedBox(height: 6),
          const Text(
            'يرسل طلب GET /api/mobile/health بدون مصادقة لتأكيد إمكانية الوصول.',
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
                  : const Icon(Icons.network_check, size: 18),
              label: const Text('تحقّق من الاتصال'),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
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
    final color = success ? AppTheme.success : AppTheme.danger;
    final icon =
        success ? Icons.check_circle_outline : Icons.error_outline;
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'الجهاز النشط'),
          const SizedBox(height: 8),
          if (!hasDevice)
            const Text(
              'لم يتم اختيار جهاز نشط بعد. اختر جهازاً من تبويب "الأجهزة".',
              style: TextStyle(
                color: AppTheme.faintMuted,
                fontSize: 12.5,
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

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    // v70: dressed-up language card with a small icon container, so the
    // "coming soon" note reads as a deliberate info chip instead of a
    // plain paragraph at the bottom of the screen.
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(label: 'اللغة'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.translate_outlined,
                  color: AppTheme.indigoPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'الواجهة متاحة حالياً بالعربية فقط. '
                  'ستضاف لغات إضافية لاحقاً بعد اكتمال إعداد الترجمة.',
                  style: TextStyle(
                    color: AppTheme.softInk,
                    fontSize: 12.5,
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
