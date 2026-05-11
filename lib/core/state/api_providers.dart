/// Cross-feature Riverpod providers that wrap the API client.
///
/// Lives in `core/state` rather than `core/api` so feature repositories can
/// depend on it without pulling Riverpod into the raw HTTP layer.
library;

export 'app_session.dart' show apiClientProvider, secureTokenStorageProvider;
