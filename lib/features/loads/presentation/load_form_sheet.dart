import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../devices/data/device_models.dart';
import '../../devices/data/devices_repository.dart';
import '../data/load_models.dart';
import '../data/loads_repository.dart';

/// نموذج إضافة / تعديل حمل (v93).
///
/// Driven by `POST /api/mobile/loads` (create) and
/// `PATCH /api/mobile/loads/:id` (update). Backend whitelist (per
/// `_mobile_apply_load_fields` in the backend blueprint):
///   * name      — required, max 120 chars.
///   * power_w   — required, positive number.
///   * priority  — 1..99, default 1.
///   * device_id — optional (must belong to the user).
///   * is_enabled — boolean.
///
/// The sheet returns `true` on a successful create/update so the caller
/// can invalidate the loads list provider; returns `null` when cancelled.
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
    _priority = TextEditingController(
      text: (ex?.priority ?? 1).toString(),
    );
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
    final devices = ref.watch(devicesListProvider).valueOrNull ??
        const <Device>[];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.softBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: AppCard(
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEdit ? 'تعديل حمل' : 'إضافة حمل',
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
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
                      color: AppTheme.faintMuted,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _power,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'القدرة (W)',
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
                  const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'حالة الحمل',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        activeThumbColor: AppTheme.indigoPrimary,
                        onChanged: (v) => setState(() => _isEnabled = v),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEnabled ? 'مفعّل' : 'موقوف',
                        style: TextStyle(
                          color: _isEnabled
                              ? AppTheme.success
                              : AppTheme.faintMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 18, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.danger,
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
                  const SizedBox(height: 16),
                  SizedBox(
                    height: AppTheme.formControlHeight + 4,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_isEdit ? Icons.save : Icons.add,
                              size: 18),
                      label: Text(_isEdit ? 'حفظ التعديل' : 'إضافة الحمل'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
