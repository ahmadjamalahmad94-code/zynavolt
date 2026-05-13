import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/device_models.dart';
import '../data/devices_repository.dart';
import '../state/selected_device_provider.dart';
import 'add_device_screen.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesListProvider);
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(title: const Text('الأجهزة')),
      // v48: subscriber-facing entry point to the add-device flow.
      // Uses Navigator.push (not go_router) because the brief's
      // allow-list does not include `lib/app/app_router.dart` —
      // adding a named route entry is out-of-scope for v48.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDeviceFlow(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('إضافة جهاز'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(devicesListProvider),
          child: devices.when(
            // v71: scrollable loading wrapper for consistent
            // RefreshIndicator behaviour across all states.
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: const [
                AppLoading(message: 'جارٍ تحميل أجهزتك...'),
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
                          message: 'تعذّر تحميل الأجهزة.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(devicesListProvider),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    // v48: copy updated to point users at the new
                    // in-app add-device FAB instead of asking them
                    // to fall back to the web portal.
                    AppEmptyState(
                      icon: Icons.solar_power_outlined,
                      title: 'لا توجد أجهزة بعد',
                      subtitle:
                          'اضغط زر «إضافة جهاز» في الأسفل لربط جهازك الأول.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = items[i];
                  final isSelected = activeId == d.id;
                  return _DeviceTile(
                    device: d,
                    isSelected: isSelected,
                    // v47: tap opens the read-only Device Details screen.
                    // The set-active action now lives there.
                    onTap: () => context.push(AppRoutes.deviceDetail(d.id)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// v48: opens [AddDeviceScreen] and refreshes the device list when
  /// the user successfully creates one. Uses Navigator.push instead
  /// of a go_router-named route because the v48 brief's allow-list
  /// does not include `lib/app/app_router.dart`.
  Future<void> _openAddDeviceFlow(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    if (created == true) {
      ref.invalidate(devicesListProvider);
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final Device device;
  final bool isSelected;
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
          borderColor: isSelected ? AppTheme.indigoBright : AppTheme.line,
          background: isSelected ? AppTheme.indigoSoft : AppTheme.surface,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.surface
                      : AppTheme.indigoSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.solar_power_outlined,
                  color: AppTheme.indigoPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            device.name.isNotEmpty ? device.name : '—',
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const _ActivePill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceType.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.faintMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                  active: device.isActive,
                  status: device.connectionStatus),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.indigoPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'نشط',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.status});
  final bool active;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ok = active && status.toLowerCase() == 'ok';
    final color = ok ? AppTheme.success : AppTheme.faintMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        ok ? 'متصل' : (status.isNotEmpty ? status : 'غير متصل'),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
