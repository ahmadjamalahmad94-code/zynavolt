// Arabic labels for raw support-case slugs (v81).
//
// The backend's `_case_payload` emits `priority`, `status`, `category`
// as English short keywords (`high`, `open`, `support`, …). Without a
// mapping, these chips render in English which breaks the Arabic-first
// rule. Falls back to the raw slug for unknown keys so the chip always
// renders something readable.

class SupportLabels {
  const SupportLabels._();

  static const Map<String, String> _priority = {
    'low': 'منخفضة',
    'normal': 'عادية',
    'medium': 'متوسطة',
    'high': 'عالية',
    'urgent': 'عاجلة',
    'critical': 'حرجة',
  };

  static const Map<String, String> _status = {
    'new': 'جديدة',
    'open': 'مفتوحة',
    'pending': 'قيد المعالجة',
    'waiting': 'قيد الانتظار',
    'in_progress': 'قيد التنفيذ',
    'resolved': 'محلولة',
    'closed': 'مغلقة',
    'cancelled': 'ملغاة',
    'canceled': 'ملغاة',
  };

  static const Map<String, String> _category = {
    'general': 'عام',
    'support': 'الدعم',
    'technical': 'تقني',
    'billing': 'فواتير',
    'account': 'الحساب',
    'device': 'الأجهزة',
    'feature': 'ميزة',
    'bug': 'خطأ',
  };

  static String priorityLabel(String slug) {
    final n = slug.trim().toLowerCase();
    return _priority[n] ?? slug;
  }

  static String statusLabel(String slug) {
    final n = slug.trim().toLowerCase();
    return _status[n] ?? slug;
  }

  static String categoryLabel(String slug) {
    final n = slug.trim().toLowerCase();
    return _category[n] ?? slug;
  }
}
