// Mirror of GET /api/mobile/loads data envelope.
//
// Backend builder: `_mobile_load_payload` in `app/blueprints/mobile_api.py`.
//
// v48 is read-only foundation:
//   - control_type is always `persisted_preference` from the server.
//   - execution_note explicitly tells us the backend does not toggle real
//     hardware. We surface neither field in the UI in v48 (no toggling).
//   - is_enabled is parsed and rendered as a *status badge only*, never
//     wired to an action.

class UserLoad {
  UserLoad({
    required this.id,
    required this.name,
    required this.powerW,
    required this.priority,
    required this.isEnabled,
    required this.deviceId,
    required this.createdAt,
  });

  factory UserLoad.fromJson(Map<String, dynamic> json) {
    double n(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int i(Object? v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? iOrNull(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        if (v.isEmpty) return null;
        return int.tryParse(v);
      }
      return null;
    }

    return UserLoad(
      id: i(json['id']),
      name: (json['name'] ?? '').toString(),
      powerW: n(json['power_w']),
      priority: i(json['priority'], fallback: 1),
      isEnabled: json['is_enabled'] == true,
      deviceId: iOrNull(json['device_id']),
      createdAt: json['created_at']?.toString(),
    );
  }

  final int id;
  final String name;
  final double powerW;
  final int priority;
  final bool isEnabled;
  final int? deviceId;
  final String? createdAt;
}

/// Describes the scope of the `/loads` list response. `mode` is either
/// `device` (filtered by `?device_id=`) or `all` (the user's full load
/// catalog, unfiltered). We mirror it verbatim so the UI can be honest
/// about what is being shown.
class LoadsScope {
  LoadsScope({required this.mode, required this.deviceId});

  factory LoadsScope.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final raw = j['device_id'];
    int? deviceId;
    if (raw is int) {
      deviceId = raw;
    } else if (raw is num) {
      deviceId = raw.toInt();
    } else if (raw is String && raw.isNotEmpty) {
      deviceId = int.tryParse(raw);
    }
    return LoadsScope(
      mode: (j['mode'] ?? '').toString(),
      deviceId: deviceId,
    );
  }

  /// `device` or `all`.
  final String mode;
  final int? deviceId;

  bool get isAll => mode == 'all' || (mode.isEmpty && deviceId == null);
}

class LoadsPage {
  LoadsPage({
    required this.items,
    required this.total,
    required this.scope,
    required this.deviceName,
  });

  factory LoadsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <UserLoad>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(UserLoad.fromJson(entry));
        } else if (entry is Map) {
          items.add(UserLoad.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    final total =
        json['total'] is int ? json['total'] as int : items.length;
    final device = (json['device'] as Map?)?.cast<String, dynamic>();
    return LoadsPage(
      items: items,
      total: total,
      scope: LoadsScope.fromJson(
        (json['scope'] as Map?)?.cast<String, dynamic>(),
      ),
      deviceName: (device?['name'] ?? '').toString(),
    );
  }

  final List<UserLoad> items;
  final int total;
  final LoadsScope scope;

  /// Convenience: the resolved device name when scope is `device`. Empty
  /// string if the list is global / device payload was absent.
  final String deviceName;
}
