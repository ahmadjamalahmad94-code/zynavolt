import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/state/auto_refresh.dart';
// v100 — app_card import removed; the redesigned tile uses a
// hand-rolled glossy gradient container instead.
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

    // v100 — Devices on the design system: gradient backdrop +
    // glossy device tiles + branded FAB.
    // v101 — 60 s auto-refresh. The list view's main job is showing
    // online/offline + name + plant — none of that drifts as fast as
    // live readings, so a longer cadence is plenty.
    return AutoRefreshScope(
      interval: const Duration(seconds: 60),
      targets: [devicesListProvider],
      child: ZynScreen(
        hero: const ZynPageHero(
          title: 'الأجهزة',
          subtitle: 'الأجهزة المرتبطة بحسابك وحالة الاتصال.',
          showBackButton: false,
        ),
        extendBody: true,
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            boxShadow: [
              BoxShadow(
                color: ZynColors.primary500.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _openAddDeviceFlow(context, ref),
            elevation: 0,
            backgroundColor: ZynColors.primary700,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'إضافة جهاز',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZynRadii.pill),
            ),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
          ),
        ),
        child: devices.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppLoading(message: 'جارٍ تحميل أجهزتك...'),
          ),
          error: (err, _) => AppErrorState(
            error: err is ApiException
                ? err
                : ApiException(
                    message: 'تعذّر تحميل الأجهزة.',
                    kind: ApiErrorKind.unknown,
                  ),
            onRetry: () => ref.invalidate(devicesListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const ZynEmptyState(
                icon: Icons.solar_power_outlined,
                title: 'لا توجد أجهزة بعد',
                subtitle:
                    'اضغط زر «إضافة جهاز» في الأسفل لربط جهازك الأول.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _DeviceTile(
                    device: items[i],
                    isSelected: activeId == items[i].id,
                    onTap: () =>
                        context.push(AppRoutes.deviceDetail(items[i].id)),
                  ),
                  if (i < items.length - 1)
                    const SizedBox(height: ZynSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// v48: opens [AddDeviceScreen] and refreshes the device list when
  /// the user successfully creates one. Uses Navigator.push instead
  /// of a go_router-named route because the v48 brief's allow-list
  /// does not include `lib/app/app_router.dart`.
  Future<void> _openAddDeviceFlow(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddDeviceScreen()));
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
    // v100 — glossy gradient tile with a filled gradient icon glyph.
    final accent = isSelected ? ZynColors.primary700 : ZynColors.primary500;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                accent.withValues(alpha: isSelected ? 0.10 : 0.05),
              ],
            ),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.45)
                  : ZynColors.line,
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isSelected ? 0.20 : 0.10),
                blurRadius: 16,
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
                // Gradient icon glyph
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withValues(alpha: 0.78)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.42),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.solar_power_rounded,
                    color: Colors.white,
                    size: 22,
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
                                color: ZynColors.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.1,
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
                      const SizedBox(height: 3),
                      Text(
                        device.deviceType.toUpperCase(),
                        style: const TextStyle(
                          color: ZynColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  active: device.isActive,
                  status: device.connectionStatus,
                ),
              ],
            ),
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
        color: ZynColors.primary700,
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
    final color = ok ? ZynColors.success : ZynColors.muted;
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
