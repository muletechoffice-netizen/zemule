import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/services/search_service.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider({required SearchService searchService})
    : _searchService = searchService {
    _loadRecentSearches();
  }

  final SearchService _searchService;

  String _searchQuery = '';
  List<Business> _searchResults = <Business>[];
  List<String> _recentSearches = <String>[];
  bool _isLoading = false;
  String _sortBy = 'distance';
  Map<String, dynamic> _filters = <String, dynamic>{
    'premiumOnly': false,
    'openNow': false,
  };

  String get searchQuery => _searchQuery;
  List<Business> get searchResults => _searchResults;
  List<String> get recentSearches => _recentSearches;
  bool get isLoading => _isLoading;
  String get sortBy => _sortBy;
  Map<String, dynamic> get filters => _filters;

  void updateQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> performSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      _isLoading = false;
      _searchResults = <Business>[];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _searchResults = await _searchService.searchBusinesses(
        query,
        filters: <String, dynamic>{..._filters, 'sortBy': _sortBy},
      );
    } catch (_) {
      _searchResults = <Business>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void applySort(String sortBy) {
    _sortBy = sortBy;
    unawaited(performSearch());
    notifyListeners();
  }

  void applyFilters(Map<String, dynamic> filters) {
    _filters = <String, dynamic>{..._filters, ...filters};
    unawaited(performSearch());
    notifyListeners();
  }

  void addToRecentSearches(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }

    _recentSearches.removeWhere(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    _recentSearches.insert(0, normalized);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }
    notifyListeners();

    unawaited(_searchService.saveRecentSearch(normalized));
  }

  void clearRecentSearches() {
    _recentSearches = <String>[];
    notifyListeners();
    unawaited(_searchService.clearRecentSearches());
  }

  void removeRecentSearch(String query) {
    _recentSearches.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    notifyListeners();
    unawaited(_searchService.removeRecentSearch(query));
  }

  Future<void> _loadRecentSearches() async {
    _recentSearches = await _searchService.getRecentSearches();
    notifyListeners();
  }
}
