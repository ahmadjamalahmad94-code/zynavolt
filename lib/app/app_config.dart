/// Single source of truth for environment configuration.
///
/// The backend base URL can be overridden at build/run time with:
///
///   flutter run --dart-define=SOLARDEYE_API_BASE_URL=https://api.example.com
///   flutter build apk --dart-define=SOLARDEYE_API_BASE_URL=https://api.example.com
///
/// The default targets the Android emulator hitting a Flask backend on the
/// host machine's localhost. For a physical device, pass the LAN IP of the
/// machine running the backend (e.g. `http://192.168.1.50:5000`).
class AppConfig {
  const AppConfig._();

  /// Backend root. Mobile endpoints live under `<apiBaseUrl>/api/mobile/*`.
  ///
  /// - Android emulator → host loopback: `http://10.0.2.2:5000`
  /// - Physical device  → LAN IP of backend host
  /// - Staging / prod   → public HTTPS URL, supplied via --dart-define
  static const String apiBaseUrl = String.fromEnvironment(
    'SOLARDEYE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Default locale. The app is Arabic RTL-first; English is a runtime toggle
  /// that is not yet wired into the UI in v37.
  static const String defaultLocale = 'ar';

  /// Network timeouts (milliseconds).
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 20000;

  /// App version label sent on every request as a telemetry header.
  /// Bump alongside pubspec.yaml version.
  static const String appVersion = '0.1.0';

  /// Platform label sent as a telemetry header. Android-first.
  static const String appPlatform = 'android';
}
