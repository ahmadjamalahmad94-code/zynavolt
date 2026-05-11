import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/state/api_providers.dart';
import 'location_catalog_models.dart';

class LocationCatalogRepository {
  LocationCatalogRepository(this._api);

  final ApiClient _api;

  /// `GET /api/mobile/location-catalog` (Bearer-auth). Returns the canonical
  /// countries / phone prefixes / timezone groups that the backend uses to
  /// validate profile PATCH requests.
  Future<LocationCatalog> fetch() async {
    final response = await _api.get('/api/mobile/location-catalog');
    return LocationCatalog.fromJson(response.data);
  }
}

final locationCatalogRepositoryProvider =
    Provider<LocationCatalogRepository>((ref) {
  return LocationCatalogRepository(ref.watch(apiClientProvider));
});

/// Cached catalog for the duration of the session. Catalog is large but
/// effectively static — one fetch per app run is plenty.
final locationCatalogProvider = FutureProvider<LocationCatalog>((ref) {
  return ref.watch(locationCatalogRepositoryProvider).fetch();
});
