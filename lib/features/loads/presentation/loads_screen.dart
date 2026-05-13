import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../devices/state/selected_device_provider.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';
import 'load_form_sheet.dart';

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

    // v100 — gradient backdrop for visual continuity.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الأحمال'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          AppRefreshButton(
            onPressed: () => ref.invalidate(loadsListProvider),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppTheme.indigoPrimary.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.indigoPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'إضافة حمل',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          onPressed: () async {
            final ok = await showLoadFormSheet(context);
            if (ok == true) ref.invalidate(loadsListProvider);
          },
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageBackdropGradient),
        child: SafeArea(
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
                  // v71: scrollable loading wrapper for consistent
                  // RefreshIndicator behaviour across all states.
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    children: const [
                      AppLoading(message: 'جارٍ تحميل الأحمال...'),
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
      ),  // close DecoratedBox (v100)
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
    // v72: AnimatedContainer + AnimatedDefaultTextStyle so the chip
     // glides between selected and unselected states instead of snapping.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
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

    // v64: show a small "X من Y حمل" count when search filters the
    // list — gives the user honest feedback that the filter is on.
    final hasSearch = normalized.isNotEmpty && filtered.length != data.items.length;
    final leadingExtras = hasSearch ? 2 : 1;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length + leadingExtras,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ScopeBanner(
            scope: data.scope,
            deviceName: data.deviceName,
          );
        }
        if (hasSearch && index == 1) {
          return _SearchSummary(
            shown: filtered.length,
            total: data.items.length,
          );
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
              color: AppTheme.faintMuted, size: 14),
          const SizedBox(width: 6),
          Text(
            'عرض $shown من أصل $total حمل',
            style: const TextStyle(
              color: AppTheme.faintMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.indigoSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.indigoBright.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 6),
          // v86: honest disclaimer about what the toggle actually does.
          // The backend response says `executed_hardware_command: false`,
          // so the user must understand this is a saved preference only.
          const Padding(
            padding: EdgeInsets.only(right: 24),
            child: Text(
              'تغيير المفتاح يحدّث حالة الحمل في إعداداتك فقط ولا يشغّل أي جهاز كهربائي.',
              style: TextStyle(
                color: AppTheme.indigoPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v86: real toggle UI backed by `POST /api/mobile/loads/:id/toggle`.
///
/// The backend response includes `executed_hardware_command: false` —
/// flipping the switch only updates the saved preference. We surface
/// that honestly via the screen-level info banner so users never expect
/// this to physically command a relay.
class _LoadTile extends ConsumerStatefulWidget {
  const _LoadTile({required this.load});
  final UserLoad load;

  @override
  ConsumerState<_LoadTile> createState() => _LoadTileState();
}

class _LoadTileState extends ConsumerState<_LoadTile> {
  /// v90b: per-row optimistic override. `null` means the Switch shows the
  /// server's truth (`widget.load.isEnabled`). When the user taps, we set
  /// this immediately so the Switch flips with no perceptible delay, and
  /// only revert it if the backend rejects the request.
  bool? _optimistic;

  /// Prevents double-tap on the SAME row while a request is in flight.
  /// Other rows stay fully interactive.
  bool _busy = false;

  @override
  void didUpdateWidget(_LoadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the list refetches and the new server value matches our
    // optimistic guess, drop the override so future toggles compare
    // against the canonical truth.
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
      // Keep `_optimistic` until didUpdateWidget reconciles with fresh
      // server data — avoids a brief flicker back to the old value
      // between the toggle returning and the list refetch arriving.
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
        ..showSnackBar(
          SnackBar(content: Text('تعذّر تحديث الحمل: $e')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.load;
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
          const SizedBox(width: 8),
          // v90b: optimistic Switch. The toggle reflects the user's
          // intent immediately; if the backend later rejects the change,
          // the catch block flips `_optimistic` back. While in flight,
          // `_busy` blocks a second tap on THIS row only (other rows
          // remain fully interactive).
          Stack(
            alignment: Alignment.center,
            children: [
              Switch(
                value: _optimistic ?? load.isEnabled,
                activeThumbColor: AppTheme.indigoPrimary,
                onChanged: _busy ? null : _onToggle,
              ),
              if (_busy)
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.indigoSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'جارٍ الحفظ',
                      style: TextStyle(
                        color: AppTheme.indigoPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // v93: per-row edit / delete menu. Uses the same FAB form sheet
          // for edit (pre-filled), and a confirm-then-delete dialog.
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
          'هل تريد حذف الحمل "${widget.load.name}"؟ '
          'يُزال هذا الحمل من إعداداتك فقط ولا يؤثر على أي جهاز كهربائي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
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
      icon: const Icon(Icons.more_vert, color: AppTheme.faintMuted),
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
                  size: 18, color: AppTheme.indigoPrimary),
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
                  size: 18, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('حذف',
                  style: TextStyle(color: AppTheme.danger)),
            ],
          ),
        ),
      ],
    );
  }
}

// v86: `_EnabledBadge` removed — the per-row Switch communicates the
// same enabled/disabled state more directly. Kept the import-clean
// trail in case the badge is ever reintroduced.

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
