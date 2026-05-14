import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';
import 'load_form_sheet.dart';

/// v102 DS v1 — الأحمال.
///
/// Owner-scoped list with client-side search + scope filter (all
/// vs. active device). Per-row optimistic toggles call
/// `POST /api/mobile/loads/:id/toggle`; edit/delete use the same
/// FAB sheet (`showLoadFormSheet`). Honest disclaimer: toggling
/// updates the saved preference only, no hardware command.
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

    return ZynScreen(
      hero: ZynPageHero(
        title: 'الأحمال',
        subtitle: 'إدارة الأحمال المنزلية وأولوياتها.',
        trailing: ZynHeroActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(loadsListProvider),
        ),
      ),
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
          backgroundColor: ZynColors.primary700,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'إضافة حمل',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZynRadii.pill),
          ),
          onPressed: () async {
            final ok = await showLoadFormSheet(context);
            if (ok == true) ref.invalidate(loadsListProvider);
          },
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: ZynSpacing.md),
          page.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: AppLoading(message: 'جارٍ تحميل الأحمال...'),
            ),
            error: (err, _) => AppErrorState(
              error: err is ApiException
                  ? err
                  : ApiException(
                      message: 'تعذّر تحميل الأحمال.',
                      kind: ApiErrorKind.unknown,
                    ),
              onRetry: () => ref.invalidate(loadsListProvider),
            ),
            data: (data) => _LoadsBody(data: data, query: _query),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(
        ZynSpacing.lg,
        ZynSpacing.md,
        ZynSpacing.lg,
        ZynSpacing.xs,
      ),
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
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: ZynColors.muted,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: ZynColors.muted,
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: ZynSpacing.sm),
          Row(
            children: [
              _ScopeChip(
                label: 'كل الأحمال',
                selected: filter == LoadsScopeFilter.all,
                onTap: () => onFilterChanged(LoadsScopeFilter.all),
              ),
              const SizedBox(width: 8),
              _ScopeChip(
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

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
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
    final Color fg;
    if (disabled) {
      fg = ZynColors.muted;
    } else if (selected) {
      fg = Colors.white;
    } else {
      fg = ZynColors.primary700;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ZynRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZynRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [ZynColors.primary500, ZynColors.primary700],
                  )
                : null,
            color: selected
                ? null
                : (disabled ? ZynColors.surfaceAlt : ZynColors.surface),
            borderRadius: BorderRadius.circular(ZynRadii.pill),
            border: Border.all(
              color: selected
                  ? ZynColors.primary700
                  : (disabled
                      ? ZynColors.line
                      : ZynColors.primary500.withValues(alpha: 0.30)),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ZynColors.primary500.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            child: Text(label),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeBanner(scope: data.scope, deviceName: data.deviceName),
          const SizedBox(height: ZynSpacing.md),
          const ZynEmptyState(
            icon: Icons.bolt_outlined,
            title: 'لا توجد أحمال مضافة بعد.',
            subtitle:
                'استخدم زر "إضافة حمل" لإضافة الحمل الأوّل، أو حدّد الجهاز الفعّال أوّلاً.',
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeBanner(scope: data.scope, deviceName: data.deviceName),
          const SizedBox(height: ZynSpacing.md),
          const ZynEmptyState(
            icon: Icons.search_off_rounded,
            title: 'لا توجد نتائج مطابقة',
            subtitle: 'حاول تغيير كلمة البحث أو إزالة الفلتر.',
          ),
        ],
      );
    }

    final hasSearch =
        normalized.isNotEmpty && filtered.length != data.items.length;
    final leadingExtras = hasSearch ? 2 : 1;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filtered.length + leadingExtras,
      separatorBuilder: (_, _) => const SizedBox(height: ZynSpacing.sm),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ScopeBanner(
              scope: data.scope, deviceName: data.deviceName);
        }
        if (hasSearch && index == 1) {
          return _SearchSummary(
              shown: filtered.length, total: data.items.length);
        }
        final load = filtered[index - leadingExtras];
        return _LoadTile(load: load);
      },
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              color: ZynColors.muted, size: 14),
          const SizedBox(width: 6),
          Text(
            'عرض $shown من أصل $total حمل',
            style: const TextStyle(
              color: ZynColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ZynColors.primary50,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(
          color: ZynColors.primary500.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: ZynColors.primary700,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: ZynColors.primary700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(right: 24),
            child: Text(
              'تغيير المفتاح يحدّث حالة الحمل في إعداداتك فقط ولا يشغّل '
              'أي جهاز كهربائي.',
              style: TextStyle(
                color: ZynColors.primary700,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadTile extends ConsumerStatefulWidget {
  const _LoadTile({required this.load});

  final UserLoad load;

  @override
  ConsumerState<_LoadTile> createState() => _LoadTileState();
}

class _LoadTileState extends ConsumerState<_LoadTile> {
  bool? _optimistic;
  bool _busy = false;

  @override
  void didUpdateWidget(_LoadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_optimistic != null && widget.load.isEnabled == _optimistic) {
      _optimistic = null;
    }
  }

  Future<void> _onToggle(bool newValue) async {
    if (_busy) return;
    final previousServerValue = widget.load.isEnabled;
    setState(() {
      _optimistic = newValue;
      _busy = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadsRepositoryProvider)
          .toggle(widget.load.id, enabled: newValue);
      ref.invalidate(loadsListProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(newValue
                ? 'تم تفعيل الحمل في إعداداتك.'
                : 'تم إيقاف الحمل في إعداداتك.'),
          ),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _optimistic = previousServerValue);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimistic = previousServerValue);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('تعذّر تحديث الحمل: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.load;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZynColors.surface,
        borderRadius: BorderRadius.circular(ZynRadii.card),
        border: Border.all(color: ZynColors.line, width: 1),
        boxShadow: ZynShadows.soft(),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZynGradients.iconFill(ZynColors.warning),
              borderRadius: BorderRadius.circular(ZynRadii.inner),
              boxShadow: ZynShadows.iconGlow(ZynColors.warning),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: ZynSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  load.name.isNotEmpty ? load.name : '—',
                  style: const TextStyle(
                    color: ZynColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _LoadMetaChip(
                      icon: Icons.flash_on_outlined,
                      label: '${_fmt(load.powerW)} W',
                    ),
                    _LoadMetaChip(
                      icon: Icons.low_priority_outlined,
                      label: 'الأولوية ${load.priority}',
                    ),
                    if (load.deviceId != null)
                      _LoadMetaChip(
                        icon: Icons.solar_power_outlined,
                        label: 'الجهاز #${load.deviceId}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              Switch(
                value: _optimistic ?? load.isEnabled,
                activeThumbColor: ZynColors.primary500,
                onChanged: _busy ? null : _onToggle,
              ),
              if (_busy)
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: ZynColors.primary50,
                      borderRadius: BorderRadius.circular(ZynRadii.pill),
                    ),
                    child: const Text(
                      'جارٍ الحفظ',
                      style: TextStyle(
                        color: ZynColors.primary700,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _LoadRowMenu(load: load),
        ],
      ),
    );
  }
}

class _LoadRowMenu extends ConsumerStatefulWidget {
  const _LoadRowMenu({required this.load});

  final UserLoad load;

  @override
  ConsumerState<_LoadRowMenu> createState() => _LoadRowMenuState();
}

class _LoadRowMenuState extends ConsumerState<_LoadRowMenu> {
  bool _deleting = false;

  Future<void> _onEdit() async {
    final ok = await showLoadFormSheet(context, existing: widget.load);
    if (ok == true) ref.invalidate(loadsListProvider);
  }

  Future<void> _onDelete() async {
    if (_deleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحمل'),
        content: Text(
          'هل تريد حذف الحمل "${widget.load.name}"؟ يُزال هذا الحمل من '
          'إعداداتك فقط ولا يؤثر على أي جهاز كهربائي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZynColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loadsRepositoryProvider).delete(widget.load.id);
      ref.invalidate(loadsListProvider);
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('تم حذف الحمل.'),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('تعذّر حذف الحمل: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'إجراءات',
      icon: const Icon(Icons.more_vert, color: ZynColors.muted),
      onSelected: (v) {
        if (v == 'edit') _onEdit();
        if (v == 'delete') _onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 18, color: ZynColors.primary700),
              SizedBox(width: 8),
              Text('تعديل'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: ZynColors.danger),
              SizedBox(width: 8),
              Text('حذف', style: TextStyle(color: ZynColors.danger)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadMetaChip extends StatelessWidget {
  const _LoadMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: ZynColors.muted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ZynColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
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
