import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/services/location_service.dart';
import 'package:zemule/services/supabase_service.dart';

class SearchService {
  SearchService({required LocationService locationService, SupabaseService? supabase})
      : _locationService = locationService,
        _supabase = supabase ?? SupabaseService.instance;

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  final SupabaseService _supabase;
  final LocationService _locationService;
  Position? _cachedUserLocation;

  Future<List<Business>> searchBusinesses(
    String query, {
    Map<String, dynamic>? filters,
  }) async {
    final activeFilters = filters ?? <String, dynamic>{};
    final searchTerms = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final rows = await _supabase.listBusinesses(
      newestFirst: true,
      status: 'approved',
    );

    final premiumOnly = activeFilters['premiumOnly'] == true;
    final openNowOnly = activeFilters['openNow'] == true;
    final sortBy = (activeFilters['sortBy'] as String? ?? 'distance').toLowerCase();
    final userLocation = await _getUserLocation();

    final filtered = rows.where((data) {
      final searchable = [
        data['name'],
        data['subcategory'],
        data['main_category'],
        data['category'],
        data['description'],
        data['area'],
        data['address'],
        data['city'],
      ].join(' ').toLowerCase();

      final matchesQuery = searchTerms.isEmpty ? true : searchTerms.every(searchable.contains);
      if (!matchesQuery) {
        return false;
      }

      if (premiumOnly && (data['is_premium'] as bool? ?? false) == false) {
        return false;
      }
      if (openNowOnly && !_isOpenNow(data)) {
        return false;
      }
      return true;
    }).toList();

    final businesses = filtered.map(Business.fromMap).map((business) {
      final distance = userLocation == null || !_hasValidCoordinates(business)
          ? null
          : _locationService.calculateDistance(
              userLocation.latitude,
              userLocation.longitude,
              business.latitude,
              business.longitude,
            );
      return business.copyWith(distanceKm: distance);
    }).toList();

    _sortBusinesses(businesses, sortBy);
    return businesses;
  }

  Future<void> saveRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentSearches();
    existing.removeWhere((item) => item.toLowerCase() == normalized.toLowerCase());
    existing.insert(0, normalized);
    if (existing.length > _maxRecentSearches) {
      existing.removeRange(_maxRecentSearches, existing.length);
    }
    await prefs.setStringList(_recentSearchesKey, existing);
  }

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? <String>[];
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentSearches();
    existing.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    await prefs.setStringList(_recentSearchesKey, existing);
  }

  bool _isOpenNow(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.toLowerCase().trim();
    if (status == 'closed') {
      return false;
    }
    return true;
  }

  void _sortBusinesses(List<Business> businesses, String sortBy) {
    if (sortBy == 'rating') {
      businesses.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) {
          return ratingCompare;
        }
        return b.reviewCount.compareTo(a.reviewCount);
      });
      return;
    }

    if (sortBy == 'reviews') {
      businesses.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      return;
    }

    businesses.sort((a, b) {
      final distanceA = a.distanceKm ?? double.infinity;
      final distanceB = b.distanceKm ?? double.infinity;
      final distanceCompare = distanceA.compareTo(distanceB);
      if (distanceCompare != 0) {
        return distanceCompare;
      }
      return b.rating.compareTo(a.rating);
    });
  }

  Future<Position?> _getUserLocation() async {
    _cachedUserLocation ??=
        await _locationService.getCurrentLocationIfPermittedOrNull();
    return _cachedUserLocation;
  }

  bool _hasValidCoordinates(Business business) {
    final latitude = business.latitude;
    final longitude = business.longitude;
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }
    if (latitude == 0 && longitude == 0) {
      return false;
    }
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
