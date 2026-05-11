import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';

/// Read-only Loads list (v48 + v53 polish).
///
/// v53 adds:
///   - Local search by load name (client-side filter; no API call).
///   - Two scope chips: "كل الأحمال" and "الجهاز النشط". The second uses
///     the backend's `?device_id=` parameter via [loadsScopeFilterProvider].
///   - Better badges, retry, and refresh feedback.
///
/// v53 stays strictly read-only — no toggle, no POST, no scheduler, no
/// hardware. `control_type` and `execution_note` from the backend are
/// parsed-ignored to avoid implying a control surface that doesn't exist.
class LoadsScreen extends ConsumerStatefulWidget {
  const LoadsScreen({super.key});

  @override
  ConsumerState<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends ConsumerState<LoadsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(loadsListProvider);
    final filter = ref.watch(loadsScopeFilterProvider);
    final activeId = ref.watch(effectiveDeviceIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        title: const Text('الأحمال'),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(loadsListProvider);
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('جارٍ التحديث...'),
                    ),
                  );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Toolbar(
              query: _query,
              controller: _searchCtrl,
              onQueryChanged: (v) => setState(() => _query = v),
              filter: filter,
              activeDeviceAvailable: activeId != null,
              onFilterChanged: (f) =>
                  ref.read(loadsScopeFilterProvider.notifier).state = f,
            ),
            Expanded(
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
                  data: (data) => _LoadsBody(
                    data: data,
                    query: _query,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.query,
    required this.controller,
    required this.onQueryChanged,
    required this.filter,
    required this.activeDeviceAvailable,
    required this.onFilterChanged,
  });

  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final LoadsScopeFilter filter;
  final bool activeDeviceAvailable;
  final ValueChanged<LoadsScopeFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ابحث باسم الحمل...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FilterChip(
                label: 'كل الأحمال',
                selected: filter == LoadsScopeFilter.all,
                onTap: () => onFilterChanged(LoadsScopeFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'الجهاز النشط',
                selected: filter == LoadsScopeFilter.activeDevice,
                onTap: activeDeviceAvailable
                    ? () => onFilterChanged(LoadsScopeFilter.activeDevice)
                    : null,
                disabled: !activeDeviceAvailable,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (disabled) {
      bg = AppTheme.softBg;
      fg = AppTheme.faintMuted;
      border = AppTheme.line;
    } else if (selected) {
      bg = AppTheme.indigoPrimary;
      fg = Colors.white;
      border = AppTheme.indigoPrimary;
    } else {
      bg = AppTheme.surface;
      fg = AppTheme.indigoPrimary;
      border = AppTheme.indigoBright.withValues(alpha: 0.30);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadsBody extends StatelessWidget {
  const _LoadsBody({required this.data, required this.query});
  final LoadsPage data;
  final String query;

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? data.items
        : data.items
            .where((l) => l.name.toLowerCase().contains(normalized))
            .toList();

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

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _ScopeBanner(scope: data.scope, deviceName: data.deviceName),
          const SizedBox(height: 12),
          const AppEmptyState(
            icon: Icons.search_off,
            title: 'لا توجد نتائج مطابقة',
            subtitle: 'حاول تغيير كلمة البحث أو إزالة الفلتر.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ScopeBanner(
            scope: data.scope,
            deviceName: data.deviceName,
          );
        }
        final load = filtered[index - 1];
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
