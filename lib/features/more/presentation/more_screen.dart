import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_config.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../devices/state/selected_device_provider.dart';

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
  _HealthResult? _result;

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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الحساب',
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
                  _Row(label: 'البريد', value: user?.email ?? '—'),
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
                  _Row(label: 'منصة', value: AppConfig.appPlatform),
                  _Row(label: 'الواجهة الخلفية', value: AppConfig.apiBaseUrl),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تشخيص المطوّر',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'حقول قراءة فقط مفيدة أثناء تجريب الاتصال بالخادم.',
                    style: TextStyle(
                      color: AppTheme.faintMuted,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Row(label: 'حالة الجلسة', value: _phaseLabel(session.phase)),
                  _Row(
                    label: 'الجهاز المخزَّن',
                    value: storedDeviceId != null ? '#$storedDeviceId' : '—',
                  ),
                  _Row(
                    label: 'الجهاز الفعّال',
                    value:
                        effectiveDeviceId != null ? '#$effectiveDeviceId' : '—',
                  ),
                  _Row(
                    label: 'آخر خطأ تهيئة',
                    value: session.lastError?.message ?? '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(appSessionProvider.notifier).signOut(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              icon: const Icon(Icons.logout),
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
