import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/services/analytics_service.dart';
import 'package:zemule/services/location_service.dart';
import 'package:zemule/services/supabase_service.dart';

enum BusinessLocationFilterMode {
  none,
  gpsRadius,
  manualArea,
}

class BusinessProvider extends ChangeNotifier {
  BusinessProvider({
    required LocationService locationService,
    SupabaseService? supabase,
    AnalyticsService? analyticsService,
  })  : _locationService = locationService,
        _supabase = supabase ?? SupabaseService.instance,
        _analyticsService = analyticsService ?? AnalyticsService();

  static const double defaultNearbyRadiusKm = 5;
  static const double maxNearbyRadiusKm = 20;
  static const List<double> nearbyRadiusOptionsKm = <double>[5, 10, 15, 20];

  final LocationService _locationService;
  final SupabaseService _supabase;
  final AnalyticsService _analyticsService;

  List<Business> _businesses = <Business>[];
  List<Business> _filteredBusinesses = <Business>[];
  String _selectedCategory = 'All';
  String _mainCategoryScope = '';
  Position? _userLocation;
  String _selectedArea = '';
  String? _gpsAreaName;
  double _selectedNearbyRadiusKm = defaultNearbyRadiusKm;
  BusinessLocationFilterMode _locationFilterMode =
      BusinessLocationFilterMode.none;
  bool _isLoading = false;

  List<Business> get businesses => _businesses;
  List<Business> get filteredBusinesses => _filteredBusinesses;
  String get selectedCategory => _selectedCategory;
  Position? get userLocation => _userLocation;
  String get selectedArea => _selectedArea;
  String? get gpsAreaName => _gpsAreaName;
  double get selectedNearbyRadiusKm => _selectedNearbyRadiusKm;
  bool get isUsingGps => _locationFilterMode == BusinessLocationFilterMode.gpsRadius;
  bool get isUsingManualArea =>
      _locationFilterMode == BusinessLocationFilterMode.manualArea;
  bool get hasActiveLocationFilter =>
      (isUsingGps && _userLocation != null) ||
      (isUsingManualArea && _selectedArea.trim().isNotEmpty);
  String get locationLabel {
    if (isUsingGps) {
      final area = _gpsAreaName?.trim() ?? '';
      return area.isEmpty ? 'Near Me' : 'Near $area';
    }
    final area = _selectedArea.trim();
    return area.isEmpty ? 'All Areas' : area;
  }
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _userLocation = await _locationService.getCurrentLocationIfPermittedOrNull();
    if (_userLocation != null) {
      _locationFilterMode = BusinessLocationFilterMode.gpsRadius;
      await _updateGpsAreaName(_userLocation!);
    } else {
      _locationFilterMode = BusinessLocationFilterMode.none;
      _gpsAreaName = null;
    }
    await fetchBusinesses();
  }

  Future<void> fetchBusinesses() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!hasActiveLocationFilter) {
        _businesses = <Business>[];
        _filteredBusinesses = <Business>[];
        _isLoading = false;
        notifyListeners();
        return;
      }

      List<Map<String, dynamic>> rows;
      if (isUsingGps && _userLocation != null) {
        rows = await _supabase.listNearbyBusinesses(
          latitude: _userLocation!.latitude,
          longitude: _userLocation!.longitude,
          radiusKm: _selectedNearbyRadiusKm,
          status: 'approved',
        );
      } else {
        rows = await _supabase.listBusinesses(
          newestFirst: true,
          status: 'approved',
          areaOrCity: _selectedArea,
        );
      }
      _businesses = rows.map(Business.fromMap).toList();
      _applyFiltersAndSort();
    } catch (_) {
      _businesses = <Business>[];
      _filteredBusinesses = <Business>[];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (isUsingGps) {
      final refreshedLocation = await _locationService.getCurrentLocationOrNull();
      if (refreshedLocation != null) {
        _userLocation = refreshedLocation;
        await _updateGpsAreaName(refreshedLocation);
      } else {
        _userLocation = null;
        _gpsAreaName = null;
        _locationFilterMode = BusinessLocationFilterMode.none;
      }
    } else if (_userLocation == null) {
      _userLocation =
          await _locationService.getCurrentLocationIfPermittedOrNull();
      if (_userLocation != null) {
        await _updateGpsAreaName(_userLocation!);
      }
    }
    await fetchBusinesses();
  }

  void filterByCategory(String category) {
    final normalized = category.trim();
    _selectedCategory = normalized.isEmpty ? 'All' : normalized;
    _applyFiltersAndSort();
  }

  void setCategoryScope(String mainCategory) {
    _mainCategoryScope = _normalizeMainCategory(mainCategory);
    _selectedCategory = 'All';
    _applyFiltersAndSort();
  }

  void clearCategoryScope() {
    _mainCategoryScope = '';
    _selectedCategory = 'All';
    _applyFiltersAndSort();
  }

  Future<void> selectArea(String area) async {
    _selectedArea = area.trim();
    _locationFilterMode = _selectedArea.isEmpty
        ? BusinessLocationFilterMode.none
        : BusinessLocationFilterMode.manualArea;
    await fetchBusinesses();
  }

  Future<bool> useCurrentLocation() async {
    final location = await _locationService.getCurrentLocationOrNull();
    if (location == null) {
      return false;
    }

    _userLocation = location;
    _selectedArea = '';
    _locationFilterMode = BusinessLocationFilterMode.gpsRadius;
    await _updateGpsAreaName(location);
    await fetchBusinesses();
    return true;
  }

  Future<void> setNearbyRadius(double radiusKm) async {
    final normalizedRadius = _normalizeRadius(radiusKm);
    if (_selectedNearbyRadiusKm == normalizedRadius) {
      return;
    }

    _selectedNearbyRadiusKm = normalizedRadius;
    if (isUsingGps && _userLocation != null) {
      await fetchBusinesses();
      return;
    }
    _applyFiltersAndSort();
  }

  void sortByDistance() {
    _filteredBusinesses = List<Business>.from(_filteredBusinesses)
      ..sort(isUsingGps ? _distancePremiumComparator : _manualLocationComparator);
    notifyListeners();
  }

  void sortByRating() {
    _filteredBusinesses = List<Business>.from(_filteredBusinesses)
      ..sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) {
          return ratingCompare;
        }
        return b.reviewCount.compareTo(a.reviewCount);
      });
    notifyListeners();
  }

  List<Business> getNearbyBusinesses(double radiusKm) {
    if (!isUsingGps) {
      return <Business>[];
    }
    final normalizedRadius = _normalizeRadius(radiusKm);
    return _filteredBusinesses.where((business) {
      final distance = business.distanceKm ?? _distanceFor(business);
      return distance <= normalizedRadius;
    }).toList();
  }

  double distanceFor(Business business) =>
      business.distanceKm ?? _distanceFor(business);

  Future<void> updateUserLocation(Position location) async {
    _userLocation = location;
    _selectedArea = '';
    _locationFilterMode = BusinessLocationFilterMode.gpsRadius;
    await _updateGpsAreaName(location);
    await fetchBusinesses();
  }

  Future<Business> getBusinessByOwnerId(String ownerId) async {
    final rows = await _supabase.listBusinesses(ownerId: ownerId, limit: 1);
    if (rows.isEmpty) {
      throw StateError('Business not found for owner');
    }
    return Business.fromMap(rows.first);
  }

  Future<void> updateBusiness(String businessId, Map<String, dynamic> data) async {
    final updates = _normalizeBusinessUpdateKeys(data);
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _supabase.updateBusiness(businessId, updates);
    await fetchBusinesses();
  }

  Future<void> uploadBusinessPhotos(String businessId, List<File> photos) async {
    if (photos.isEmpty) {
      return;
    }

    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      final file = photos[i];
      final path = '$businessId/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final publicUrl = await _supabase.uploadFile(
        bucket: 'businesses',
        path: path,
        file: file,
      );
      urls.add(publicUrl);
    }

    final business = await _supabase.getBusinessById(businessId);
    final currentPhotos = ((business?['photos'] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'photos': <String>[...currentPhotos, ...urls],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await fetchBusinesses();
  }

  Future<void> replaceBusinessPhotos(
    String businessId, {
    required List<String> retainedPhotoUrls,
    List<File> newPhotos = const <File>[],
  }) async {
    final business = await _supabase.getBusinessById(businessId);
    final currentPhotos = ((business?['photos'] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    final normalizedRetained = retainedPhotoUrls.where((url) => url.trim().isNotEmpty).toList();
    final removedPaths = currentPhotos
        .where((url) => !normalizedRetained.contains(url))
        .map(_extractBusinessStoragePath)
        .whereType<String>()
        .toList();

    final uploadedUrls = <String>[];
    for (int i = 0; i < newPhotos.length; i++) {
      final file = newPhotos[i];
      final path = '$businessId/photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final publicUrl = await _supabase.uploadFile(
        bucket: 'businesses',
        path: path,
        file: file,
      );
      uploadedUrls.add(publicUrl);
    }

    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'photos': <String>[...normalizedRetained, ...uploadedUrls],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (removedPaths.isNotEmpty) {
      try {
        await _supabase.removeFiles(bucket: 'businesses', paths: removedPaths);
      } catch (error) {
        debugPrint('Failed to remove old business photos: $error');
      }
    }

    await fetchBusinesses();
  }

  Future<void> addService(String businessId, Map<String, dynamic> service) async {
    final business = await _supabase.getBusinessById(businessId);
    final current = (business?['services'] as List?) ?? <dynamic>[];
    final serviceId = '${DateTime.now().millisecondsSinceEpoch}';
    final services = current.map(_normalizeMap).toList()
      ..add(<String, dynamic>{
        'id': serviceId,
        'name': service['name']?.toString().trim() ?? '',
        'price': service['price']?.toString().trim() ?? '',
      });

    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'services': services,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateService(
    String businessId,
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    final business = await _supabase.getBusinessById(businessId);
    final current = (business?['services'] as List?) ?? <dynamic>[];
    final services = current.map(_normalizeMap).map((service) {
      if ((service['id']?.toString() ?? '') != serviceId) {
        return service;
      }
      return <String, dynamic>{...service, ...data, 'id': serviceId};
    }).toList();

    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'services': services,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteService(String businessId, String serviceId) async {
    final business = await _supabase.getBusinessById(businessId);
    final current = (business?['services'] as List?) ?? <dynamic>[];
    final services = current.map(_normalizeMap).where((service) {
      return (service['id']?.toString() ?? '') != serviceId;
    }).toList();

    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'services': services,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateOpeningHours(String businessId, Map<String, dynamic> hours) async {
    await _supabase.updateBusiness(businessId, <String, dynamic>{
      'opening_hours': hours,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, int>> getStats(
    String businessId, {
    String period = 'month',
  }) async {
    return _analyticsService.calculateTrends(businessId, period: period);
  }

  Future<void> replyToReview(String businessId, String reviewId, String reply) async {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _supabase.updateReview(reviewId, <String, dynamic>{
      'owner_reply': <String, dynamic>{
        'message': trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    });
  }

  void _applyFiltersAndSort() {
    Iterable<Business> working = _businesses;

    if (_mainCategoryScope.isNotEmpty) {
      working = working.where((business) {
        final current = _normalizeMainCategory(business.mainCategory);
        return current == _mainCategoryScope;
      });
    }

    if (_selectedCategory != 'All') {
      working = working.where((business) {
        final selected = _normalizeCategory(_selectedCategory);
        final current = _normalizeCategory(business.subcategory);
        if (selected == 'more') {
          return !_knownCategories.contains(current);
        }
        return _categoryMatches(selected, current);
      });
    }

    if (!hasActiveLocationFilter) {
      _filteredBusinesses = <Business>[];
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (isUsingManualArea) {
      final selectedArea = _normalizeArea(_selectedArea);
      working = working.where((business) {
        final businessArea = _normalizeArea(business.area);
        final businessCity = _normalizeArea(business.city);
        return businessArea == selectedArea ||
            businessCity == selectedArea ||
            businessArea.contains(selectedArea) ||
            businessCity.contains(selectedArea);
      });
    } else if (isUsingGps && _userLocation != null) {
      working = working.where(
        (business) =>
            _hasValidCoordinates(business) &&
            (business.distanceKm ?? _distanceFor(business)) <=
                _selectedNearbyRadiusKm,
      );
    }

    _filteredBusinesses = working
        .map((business) => business.copyWith(
              distanceKm: isUsingGps ? (business.distanceKm ?? _distanceFor(business)) : null,
            ))
        .toList()
      ..sort(isUsingGps ? _distancePremiumComparator : _manualLocationComparator);

    _isLoading = false;
    notifyListeners();
  }

  int _distancePremiumComparator(Business a, Business b) {
    final distanceA = a.distanceKm ?? _distanceFor(a);
    final distanceB = b.distanceKm ?? _distanceFor(b);
    final distanceCompare = distanceA.compareTo(distanceB);
    if (distanceCompare != 0) {
      return distanceCompare;
    }
    if (a.isPremium != b.isPremium) {
      return a.isPremium ? -1 : 1;
    }
    return b.rating.compareTo(a.rating);
  }

  int _manualLocationComparator(Business a, Business b) {
    if (a.isPremium != b.isPremium) {
      return a.isPremium ? -1 : 1;
    }
    final ratingCompare = b.rating.compareTo(a.rating);
    if (ratingCompare != 0) {
      return ratingCompare;
    }
    return b.reviewCount.compareTo(a.reviewCount);
  }

  double _distanceFor(Business business) {
    final location = _userLocation;
    if (location == null) {
      return 0;
    }
    return _locationService.calculateDistance(
      location.latitude,
      location.longitude,
      business.latitude,
      business.longitude,
    );
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

  Future<void> _updateGpsAreaName(Position position) async {
    _gpsAreaName = await _locationService.getAreaNameFromCoordinates(
      position.latitude,
      position.longitude,
    );
  }

  double _normalizeRadius(double value) {
    if (!value.isFinite) {
      return defaultNearbyRadiusKm;
    }
    final clamped = value.clamp(
      defaultNearbyRadiusKm,
      maxNearbyRadiusKm,
    ).toDouble();
    for (final option in nearbyRadiusOptionsKm) {
      if (option == clamped) {
        return option;
      }
    }
    return nearbyRadiusOptionsKm.first;
  }

  bool _categoryMatches(String selected, String current) {
    if (current == selected) {
      return true;
    }
    if (selected == 'gaming') {
      return current == 'gaming' || current == 'gaming station';
    }
    if (selected == 'gaming station') {
      return current == 'gaming station' || current == 'gaming';
    }
    return false;
  }

  String _normalizeArea(String area) {
    return area
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeMainCategory(String category) {
    return category
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeCategory(String category) {
    final value = category.toLowerCase().trim();
    if (value.isEmpty) return value;

    if (value.contains('auto') && value.contains('electric')) return 'auto electrician';
    if (value.contains('electric')) return 'electrician';
    if (value.contains('plumb')) return 'plumber';
    if (value.contains('paint')) return 'painter';
    if (value.contains('carp')) return 'carpenter';
    if (value.contains('lock')) return 'locksmith';
    if (value.contains('garden')) return 'gardener';
    if (value.contains('pool')) return 'pool cleaner';

    if (value.contains('mechanic')) return 'mechanic';
    if (value.contains('car wash') || value.contains('wash')) return 'car wash';
    if (value.contains('tow')) return 'towing';
    if (value.contains('tire')) return 'tire shop';

    if (value.contains('nail')) return 'nail salon';
    if (value.contains('barber')) return 'barber';
    if (value.contains('hair')) return 'hair salon';
    if (value.contains('salon')) return 'hair salon';
    if (value.contains('spa')) return 'spa';
    if (value.contains('makeup')) return 'makeup artist';
    if (value.contains('tailor')) return 'tailor';
    if (value.contains('laundry') || value.contains('dry')) return 'laundry';

    if (value.contains('gym')) return 'gym';
    if (value.contains('trainer')) return 'personal trainer';
    if (value.contains('doctor')) return 'doctor';
    if (value.contains('pharm')) return 'pharmacy';
    if (value.contains('dent')) return 'dentist';

    if (value.contains('photo')) return 'photographer';
    if (value.contains('video')) return 'videographer';
    if (value.contains('dj')) return 'dj';
    if (value.contains('planner')) return 'event planner';
    if (value.contains('cater')) return 'caterer';

    if (value.contains('phone')) return 'phone repair';
    if (value.contains('computer')) return 'computer repair';
    if (value.contains('web')) return 'web designer';
    if (value.contains('graphic')) return 'graphic designer';

    if (value.contains('account')) return 'accountant';
    if (value.contains('law')) return 'lawyer';
    if (value.contains('estate')) return 'real estate agent';
    if (value.contains('clean')) return 'cleaner';

    if (value.contains('gaming') && value.contains('station')) return 'gaming station';
    if (value.contains('gaming') || value.contains('game')) return 'gaming';
    if (value.contains('venue')) return 'event venue';
    if (value.contains('karaoke')) return 'karaoke bar';

    if (value.contains('tutor')) return 'tutor';
    if (value.contains('music')) return 'music teacher';
    if (value.contains('training')) {
      if (value.contains('computer')) return 'computer training';
      return 'training';
    }
    return value;
  }

  static const Set<String> _knownCategories = <String>{
    'electrician',
    'plumber',
    'painter',
    'carpenter',
    'locksmith',
    'gardener',
    'pool cleaner',
    'mechanic',
    'car wash',
    'towing',
    'tire shop',
    'auto electrician',
    'hair salon',
    'barber',
    'nail salon',
    'spa',
    'makeup artist',
    'tailor',
    'laundry',
    'gym',
    'personal trainer',
    'doctor',
    'pharmacy',
    'dentist',
    'photographer',
    'videographer',
    'dj',
    'event planner',
    'caterer',
    'phone repair',
    'computer repair',
    'web designer',
    'graphic designer',
    'accountant',
    'lawyer',
    'real estate agent',
    'cleaner',
    'gaming station',
    'gaming',
    'event venue',
    'karaoke bar',
    'tutor',
    'music teacher',
    'computer training',
  };

  Map<String, dynamic> _normalizeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeBusinessUpdateKeys(Map<String, dynamic> data) {
    final map = <String, dynamic>{};
    for (final entry in data.entries) {
      switch (entry.key) {
        case 'mainCategory':
          map['main_category'] = entry.value;
          break;
        case 'subcategory':
          map['subcategory'] = entry.value;
          map['category'] = entry.value;
          break;
        case 'phoneNumber':
          map['phone'] = entry.value;
          break;
        case 'whatsappNumber':
          map['whatsapp'] = entry.value;
          break;
        case 'photoUrls':
          map['photos'] = entry.value;
          break;
        case 'reviewCount':
          map['review_count'] = entry.value;
          break;
        case 'isPremium':
          map['is_premium'] = entry.value;
          break;
        case 'premiumExpiry':
          map['premium_expiry'] = entry.value;
          break;
        case 'openingHours':
          map['opening_hours'] = entry.value;
          break;
        default:
          map[entry.key] = entry.value;
      }
    }
    return map;
  }

  String? _extractBusinessStoragePath(String url) {
    const marker = '/object/public/businesses/';
    final idx = url.indexOf(marker);
    if (idx == -1) {
      return null;
    }
    return url.substring(idx + marker.length);
  }
}
