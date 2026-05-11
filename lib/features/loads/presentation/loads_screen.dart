import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';

/// Read-only Loads list (v48).
///
/// Renders GET /api/mobile/loads as calm soft cards. v48 is the foundation
/// only: every load is read-only here. We surface the enabled/disabled
/// state as a badge — there is no toggle action, no POST, no scheduler
/// trigger. The backend `control_type` field is `persisted_preference`
/// (per backend), which we deliberately do not expose in the UI to avoid
/// implying a control surface that doesn't exist yet.
class LoadsScreen extends ConsumerWidget {
  const LoadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(loadsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الأحمال'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(loadsListProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(loadsListProvider),
          child: page.when(
            loading: () =>
                const AppLoading(message: 'جارٍ تحميل الأحمال...'),
            error: (err, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AppErrorState(
                  error: err is ApiException
                      ? err
                      : ApiException(
                          message: 'تعذّر تحميل الأحمال.',
                          kind: ApiErrorKind.unknown,
                        ),
                  onRetry: () => ref.invalidate(loadsListProvider),
                ),
              ],
            ),
            data: (data) => _LoadsBody(data: data),
          ),
        ),
      ),
    );
  }
}

class _LoadsBody extends StatelessWidget {
  const _LoadsBody({required this.data});
  final LoadsPage data;

  @override
  Widget build(BuildContext context) {
    if (data.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _ScopeBanner(scope: data.scope, deviceName: data.deviceName),
          const SizedBox(height: 12),
          const AppEmptyState(
            icon: Icons.bolt_outlined,
            title: 'لا توجد أحمال مضافة بعد.',
            subtitle:
                'ستظهر هنا قائمة الأحمال بعد إضافتها من الواجهة الخلفية.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: data.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ScopeBanner(
            scope: data.scope,
            deviceName: data.deviceName,
          );
        }
        final load = data.items[index - 1];
        return _LoadTile(load: load);
      },
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({required this.scope, required this.deviceName});
  final LoadsScope scope;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final isAll = scope.isAll;
    final text = isAll
        ? 'هذه قائمة الأحمال المتاحة لحسابك.'
        : (deviceName.isNotEmpty
            ? 'أحمال الجهاز: $deviceName'
            : 'أحمال جهاز #${scope.deviceId ?? '—'}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.indigoBright.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.indigoPrimary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.indigoPrimary,
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

class _LoadTile extends StatelessWidget {
  const _LoadTile({required this.load});
  final UserLoad load;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
            child: const Icon(
              Icons.bolt_outlined,
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
                        load.name.isNotEmpty ? load.name : '—',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _EnabledBadge(enabled: load.isEnabled),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                      icon: Icons.flash_on_outlined,
                      label: '${_fmt(load.powerW)} W',
                    ),
                    _MetaChip(
                      icon: Icons.low_priority_outlined,
                      label: 'الأولوية ${load.priority}',
                    ),
                    if (load.deviceId != null)
                      _MetaChip(
                        icon: Icons.solar_power_outlined,
                        label: 'الجهاز #${load.deviceId}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnabledBadge extends StatelessWidget {
  const _EnabledBadge({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.success : AppTheme.faintMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        enabled ? 'مفعّل' : 'موقوف',
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.faintMuted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.faintMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _fmt(double v) {
  if (v == 0) return '0';
  final abs = v.abs();
  if (abs >= 100) return v.toStringAsFixed(0);
  if (abs >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}
