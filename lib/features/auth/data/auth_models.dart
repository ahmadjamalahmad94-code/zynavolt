// Auth-flow value types. Field names mirror the backend JSON exactly
// (snake_case → camelCase) so screens never have to translate again.

/// Current signed-in user, as returned by GET /api/mobile/auth/me.
class AuthUser {
  AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.isActive,
    required this.preferredLanguage,
    required this.country,
    required this.city,
    required this.timezone,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.selectedDeviceId,
    required this.onboardingCompleted,
    required this.onboardingStep,
    required this.accountRestricted,
    required this.restrictionReason,
    required this.canWrite,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final onboarding = (json['onboarding'] as Map?)?.cast<String, dynamic>();
    return AuthUser(
      id: (json['id'] ?? 0) as int,
      username: (json['username'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      isAdmin: json['is_admin'] == true,
      isActive: json['is_active'] == true,
      preferredLanguage:
          (json['preferred_language'] ?? 'ar').toString(),
      country: (json['country'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      timezone: (json['timezone'] ?? '').toString(),
      phoneCountryCode: (json['phone_country_code'] ?? '').toString(),
      phoneNumber: (json['phone_number'] ?? '').toString(),
      selectedDeviceId: json['selected_device_id'] is int
          ? json['selected_device_id'] as int
          : null,
      onboardingCompleted: onboarding?['completed'] == true,
      onboardingStep: (onboarding?['step'] ?? '').toString(),
      accountRestricted: json['account_restricted'] == true,
      restrictionReason: (json['restriction_reason'] ?? '').toString(),
      canWrite: json['can_write'] != false,
    );
  }

  final int id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final bool isAdmin;
  final bool isActive;
  final String preferredLanguage;
  final String country;
  final String city;
  final String timezone;
  final String phoneCountryCode;
  final String phoneNumber;
  final int? selectedDeviceId;
  final bool onboardingCompleted;
  final String onboardingStep;
  final bool accountRestricted;
  final String restrictionReason;
  final bool canWrite;
}

/// Result of POST /api/mobile/auth/login.
class AuthLoginResult {
  AuthLoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.canWrite,
    required this.accountRestricted,
  });

  factory AuthLoginResult.fromJson(Map<String, dynamic> json) =>
      AuthLoginResult(
        accessToken: (json['access_token'] ?? '').toString(),
        refreshToken: (json['refresh_token'] ?? '').toString(),
        expiresInSeconds:
            (json['expires_in'] is int) ? json['expires_in'] as int : 0,
        canWrite: json['can_write'] != false,
        accountRestricted: json['account_restricted'] == true,
      );

  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final bool canWrite;
  final bool accountRestricted;
}
