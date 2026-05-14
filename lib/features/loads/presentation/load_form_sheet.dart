import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/design/zyn_components.dart';
import '../../../core/design/zyn_tokens.dart';
import '../../devices/data/device_models.dart';
import '../../devices/data/devices_repository.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';

/// v102 DS v1 — نموذج إضافة / تعديل حمل (bottom sheet).
///
/// Posts `POST /api/mobile/loads` (create) or `PATCH /api/mobile/loads/:id`
/// (update). Returns `true` on success so the caller can invalidate the
/// loads list; `null` when cancelled.
Future<bool?> showLoadFormSheet(
  BuildContext context, {
  UserLoad? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _LoadFormSheet(existing: existing),
    ),
  );
}

class _LoadFormSheet extends ConsumerStatefulWidget {
  const _LoadFormSheet({this.existing});

  final UserLoad? existing;

  @override
  ConsumerState<_LoadFormSheet> createState() => _LoadFormSheetState();
}

class _LoadFormSheetState extends ConsumerState<_LoadFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _power;
  late final TextEditingController _priority;
  int? _deviceId;
  bool _isEnabled = true;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _name = TextEditingController(text: ex?.name ?? '');
    _power = TextEditingController(
      text: ex == null ? '' : _formatPower(ex.powerW),
    );
    _priority = TextEditingController(text: (ex?.priority ?? 1).toString());
    _deviceId = ex?.deviceId;
    _isEnabled = ex?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _power.dispose();
    _priority.dispose();
    super.dispose();
  }

  String _formatPower(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = ref.read(loadsRepositoryProvider);
    final name = _name.text.trim();
    final powerW = double.tryParse(_power.text.trim()) ?? 0;
    final priority = int.tryParse(_priority.text.trim()) ?? 1;
    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: name,
          powerW: powerW,
          priority: priority,
          deviceId: _deviceId,
          isEnabled: _isEnabled,
        );
      } else {
        await repo.create(
          name: name,
          powerW: powerW,
          priority: priority,
          deviceId: _deviceId,
          isEnabled: _isEnabled,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر حفظ الحمل: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices =
        ref.watch(devicesListProvider).valueOrNull ?? const <Device>[];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: ZynColors.bg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(ZynRadii.hero)),
        ),
        padding: const EdgeInsets.fromLTRB(
          ZynSpacing.lg,
          ZynSpacing.md,
          ZynSpacing.lg,
          ZynSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZynColors.line,
                      borderRadius: BorderRadius.circular(ZynRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: ZynSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: ZynGradients.iconFill(ZynColors.warning),
                        borderRadius: BorderRadius.circular(ZynRadii.inner),
                        boxShadow: ZynShadows.iconGlow(ZynColors.warning),
                      ),
                      child: Icon(
                        _isEdit ? Icons.edit_outlined : Icons.add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: ZynSpacing.md),
                    Expanded(
                      child: Text(
                        _isEdit ? 'تعديل حمل' : 'إضافة حمل',
                        style: const TextStyle(
                          color: ZynColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: ZynColors.muted),
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'هذا يغيّر حالة الحمل في إعداداتك ولا يعني تشغيل '
                  'جهاز كهربائي مباشرة.',
                  style: TextStyle(
                    color: ZynColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: ZynSpacing.md),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحمل',
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'اسم الحمل مطلوب.';
                    if (s.length > 120) return 'الاسم طويل جداً.';
                    return null;
                  },
                ),
                const SizedBox(height: ZynSpacing.md),
                TextFormField(
                  controller: _power,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'القدرة (واط)',
                    hintText: 'مثال: 1200',
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'القدرة مطلوبة.';
                    final n = double.tryParse(s);
                    if (n == null) return 'أدخل قيمة رقمية صحيحة.';
                    if (n <= 0) return 'يجب أن تكون القدرة أكبر من صفر.';
                    return null;
                  },
                ),
                const SizedBox(height: ZynSpacing.md),
                TextFormField(
                  controller: _priority,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'الأولوية (1 إلى 99)',
                    hintText: '1',
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'الأولوية مطلوبة.';
                    final n = int.tryParse(s);
                    if (n == null) return 'أدخل رقماً صحيحاً.';
                    if (n < 1 || n > 99) {
                      return 'القيمة يجب أن تكون بين 1 و 99.';
                    }
                    return null;
                  },
                ),
                if (devices.isNotEmpty) ...[
                  const SizedBox(height: ZynSpacing.md),
                  DropdownButtonFormField<int?>(
                    initialValue: _deviceId,
                    decoration: const InputDecoration(
                      labelText: 'الجهاز المرتبط (اختياري)',
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('بدون جهاز'),
                      ),
                      for (final d in devices)
                        DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(
                            d.name.isNotEmpty ? d.name : '#${d.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _deviceId = v),
                  ),
                ],
                const SizedBox(height: ZynSpacing.md),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: ZynColors.surface,
                    borderRadius: BorderRadius.circular(ZynRadii.inner),
                    border: Border.all(color: ZynColors.line),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'حالة الحمل',
                          style: TextStyle(
                            color: ZynColors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        activeThumbColor: ZynColors.primary500,
                        onChanged: (v) => setState(() => _isEnabled = v),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEnabled ? 'مفعّل' : 'موقوف',
                        style: TextStyle(
                          color:
                              _isEnabled ? ZynColors.success : ZynColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: ZynSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: ZynColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(ZynRadii.inner),
                      border: Border.all(
                          color: ZynColors.danger.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: ZynColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: ZynColors.danger,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: ZynSpacing.md),
                ZynButton(
                  label: _isEdit ? 'حفظ التعديل' : 'إضافة الحمل',
                  icon: _isEdit ? Icons.save_outlined : Icons.add_rounded,
                  busy: _submitting,
                  onTap: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
