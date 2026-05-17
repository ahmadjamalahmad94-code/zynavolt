import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/design/zyn_tokens.dart';
import '../../data/device_models.dart';
import '../../data/devices_repository.dart';
import '../../state/selected_device_provider.dart';

/// v102d — single-tap active-device switcher.
///
/// The chip lives in the home hero (and anywhere else a screen needs
/// "what's active right now / let me jump to another device"). On tap
/// it opens [DeviceSwitcherSheet], a compact bottom sheet that lists
/// every device on the account with its status; tapping a row swaps
/// the active selection and dismisses the sheet. No nav stack hops,
/// no detail-screen detour — the whole switch is one tap inside the
/// sheet.
class DeviceSwitcherChip extends ConsumerWidget {
  const DeviceSwitcherChip({super.key, this.onDark = true});

  /// `true` for navy hero placements (white text + faint white border).
  /// `false` for light surfaces (ink text + line border).
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(effectiveDeviceProvider);
    final devices =
        ref.watch(devicesListProvider).valueOrNull ?? const <Device>[];
    final hasMany = devices.length > 1;

    final label = active?.name.trim().isNotEmpty == true
        ? active!.name
        : 'لم يتم اختيار جهاز';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        onTap: devices.isEmpty
            ? null
            : () => DeviceSwitcherSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: 0.10)
                : ZynColors.primary50,
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            border: Border.all(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : ZynColors.primary500.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.solar_power_outlined,
                size: 13,
                color: onDark
                    ? Colors.white.withValues(alpha: 0.92)
                    : ZynColors.primary700,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.95)
                        : ZynColors.primary700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (hasMany) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 14,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : ZynColors.primary700,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet picker. One tap on a row sets that device as the
/// active one and pops the sheet. Owner-asked: no extra confirmation,
/// no detail screen detour — switching has to feel instant.
class DeviceSwitcherSheet extends ConsumerWidget {
  const DeviceSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeviceSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesListProvider);
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return SafeArea(
      top: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: ZynColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(ZynRadii.xl),
              topRight: Radius.circular(ZynRadii.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // grabber
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ZynColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'اختر الجهاز النشط',
                  style: TextStyle(
                    color: ZynColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'يتغيّر مصدر بيانات الشاشات الرئيسية فور الاختيار.',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              devicesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    err is ApiException
                        ? err.message
                        : 'تعذّر تحميل قائمة الأجهزة.',
                    style: const TextStyle(
                      color: ZynColors.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                data: (devices) {
                  if (devices.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'لا توجد أجهزة بعد. أضف جهازك من قسم الأجهزة.',
                        style: TextStyle(
                          color: ZynColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: ZynSpacing.sm),
                      itemBuilder: (_, i) {
                        final d = devices[i];
                        return _DeviceRow(
                          device: d,
                          isActive: activeId == d.id,
                          onTap: () async {
                            await ref
                                .read(selectedDeviceProvider.notifier)
                                .select(d.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.isActive,
    required this.onTap,
  });

  final Device device;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = device.connectionStatus.trim().toLowerCase();
    final online = connected == 'online' || connected == 'connected';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.card),
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: isActive
                ? ZynColors.primary50.withValues(alpha: 0.55)
                : ZynColors.surface,
            borderRadius: BorderRadius.circular(ZynRadii.card),
            border: Border.all(
              color: isActive
                  ? ZynColors.primary500.withValues(alpha: 0.40)
                  : ZynColors.line,
              width: isActive ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ZynColors.primary700,
                      ZynColors.primary500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.solar_power_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name.isNotEmpty ? device.name : '—',
                      style: const TextStyle(
                        color: ZynColors.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                online ? ZynColors.success : ZynColors.muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          online ? 'متصل' : 'غير متصل',
                          style: TextStyle(
                            color: online
                                ? ZynColors.success
                                : ZynColors.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (device.plantName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '· ${device.plantName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ZynColors.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZynColors.primary700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'النشط',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: ZynColors.primary700,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
