/// Mirror of GET /api/mobile/bootstrap response.
///
/// Skeleton only — captures enough fields for the home shell to know which
/// permissions / nav items / providers are available, plus the resolved
/// active device hint. Extend as new screens consume more of the payload.
class AppBootstrap {
  AppBootstrap({
    required this.version,
    required this.userId,
    required this.username,
    required this.role,
    required this.permissions,
    required this.navigation,
    required this.providers,
    required this.activeDeviceId,
    required this.userTimezone,
    required this.userCountry,
    required this.userCity,
  });

  factory AppBootstrap.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final perms =
        (json['permissions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final navRaw = (json['navigation'] as List?) ?? const [];
    final providersRaw = (json['providers'] as List?) ?? const [];
    return AppBootstrap(
      version: (json['version'] ?? '').toString(),
      userId: (user['id'] ?? 0) as int,
      username: (user['username'] ?? '').toString(),
      role: (user['role'] ?? '').toString(),
      permissions: perms
          .map((key, value) => MapEntry(key, value == true)),
      navigation: navRaw
          .whereType<Map<String, dynamic>>()
          .map(NavigationItem.fromJson)
          .toList(),
      providers: providersRaw
          .whereType<Map<String, dynamic>>()
          .map(BootstrapProvider.fromJson)
          .toList(),
      activeDeviceId: json['active_device_id'] is int
          ? json['active_device_id'] as int
          : null,
      userTimezone: (json['user_timezone'] ?? '').toString(),
      userCountry: (json['user_country'] ?? '').toString(),
      userCity: (json['user_city'] ?? '').toString(),
    );
  }

  final String version;
  final int userId;
  final String username;
  final String role;
  final Map<String, bool> permissions;
  final List<NavigationItem> navigation;
  final List<BootstrapProvider> providers;
  final int? activeDeviceId;
  final String userTimezone;
  final String userCountry;
  final String userCity;

  bool can(String permission) => permissions[permission] == true;
}

class NavigationItem {
  NavigationItem({
    required this.key,
    required this.endpoint,
    required this.label,
    required this.icon,
    required this.group,
    required this.order,
  });

  factory NavigationItem.fromJson(Map<String, dynamic> json) => NavigationItem(
        key: (json['key'] ?? '').toString(),
        endpoint: (json['endpoint'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        icon: (json['icon'] ?? '').toString(),
        group: (json['group'] ?? '').toString(),
        order:
            (json['order'] is int) ? json['order'] as int : 100,
      );

  final String key;
  final String endpoint;
  final String label;
  final String icon;
  final String group;
  final int order;
}

class BootstrapProvider {
  BootstrapProvider({
    required this.code,
    required this.name,
    required this.authMode,
    required this.category,
    required this.status,
  });

  factory BootstrapProvider.fromJson(Map<String, dynamic> json) =>
      BootstrapProvider(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        authMode: (json['auth_mode'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
      );

  final String code;
  final String name;
  final String authMode;
  final String category;
  final String status;
}
