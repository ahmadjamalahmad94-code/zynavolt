import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/state/app_session.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../devices/data/device_models.dart';
import '../../devices/state/selected_device_provider.dart';

/// Placeholder home tab. The full dashboard is intentionally out of v37 scope;
/// this screen only confirms the bootstrap call works and the user is loaded.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final bootstrap = ref.watch(bootstrapProvider);
    final activeDevice = ref.watch(effectiveDeviceProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الرئيسية')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bootstrapProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً ${session.user?.fullName.isNotEmpty == true ? session.user!.fullName : session.user?.username ?? ''}',
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ActiveDeviceLine(device: activeDevice),
                    const SizedBox(height: 6),
                    const Text(
                      'سيتم تحميل البيانات من واجهات Zynavolt API.',
                      style: TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              bootstrap.when(
                loading: () => const AppCard(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: AppLoading(message: 'جارٍ تحميل بيانات التهيئة...'),
                ),
                error: (err, _) {
                  final apiErr = err is ApiException
                      ? err
                      : ApiException(
                          message: 'تعذّر تحميل بيانات التهيئة.',
                          kind: ApiErrorKind.unknown,
                        );
                  return AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: AppErrorState(
                      error: apiErr,
                      onRetry: () => ref.invalidate(bootstrapProvider),
                    ),
                  );
                },
                data: (data) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تهيئة التطبيق',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Kv(label: 'إصدار الواجهة', value: data.version),
                      _Kv(
                          label: 'الموقع',
                          value:
                              [data.userCity, data.userCountry].where((s) => s.isNotEmpty).join('، ')),
                      _Kv(label: 'المنطقة الزمنية', value: data.userTimezone),
                      _Kv(
                          label: 'عدد عناصر القائمة',
                          value: '${data.navigation.length}'),
                      _Kv(
                          label: 'عدد المزوّدين',
                          value: '${data.providers.length}'),
                      _Kv(
                          label: 'الجهاز النشط',
                          value: data.activeDeviceId != null
                              ? '#${data.activeDeviceId}'
                              : 'غير محدد بعد'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const AppCard(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: AppEmptyState(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'لوحة المعلومات قادمة قريباً',
                  subtitle:
                      'سيتم بناء واجهة الطاقة الحيّة في مرحلة لاحقة عبر واجهة /api/mobile/dashboard دون أي حسابات داخل التطبيق.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDeviceLine extends StatelessWidget {
  const _ActiveDeviceLine({required this.device});

  final Device? device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    if (d == null) {
      return Row(
        children: const [
          Icon(Icons.info_outline, size: 14, color: AppTheme.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'اختر جهازاً من تبويب الأجهزة.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.solar_power_outlined,
            size: 14, color: AppTheme.indigoPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'الجهاز النشط: ${d.name.isNotEmpty ? d.name : '#${d.id}'}',
            style: const TextStyle(
              color: AppTheme.softInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});
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
              value.isEmpty ? '—' : value,
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

