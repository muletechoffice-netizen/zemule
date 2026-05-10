import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/services/supabase_service.dart';
import 'package:zemule/utils/opening_hours.dart';

class BusinessServiceItem {
  const BusinessServiceItem({required this.name, required this.price});

  final String name;
  final String price;
}

class BusinessReview {
  const BusinessReview({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.photoUrls,
  });

  final String id;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final List<String> photoUrls;
}

class BusinessDetailProvider extends ChangeNotifier {
  BusinessDetailProvider({
    required this.businessId,
    SupabaseService? supabase,
  }) : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;
  final String businessId;

  Business? _business;
  List<BusinessReview> _reviews = <BusinessReview>[];
  List<Business> _similarBusinesses = <Business>[];
  List<BusinessServiceItem> _services = <BusinessServiceItem>[];
  bool _isFavorite = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _openingHoursText;
  String? _foundedText;

  Business? get business => _business;
  List<BusinessReview> get reviews => _reviews;
  List<Business> get similarBusinesses => _similarBusinesses;
  List<BusinessServiceItem> get services => _services;
  bool get isFavorite => _isFavorite;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get openingHoursText => _openingHoursText;
  String? get foundedText => _foundedText;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await fetchBusinessDetails();
      await Future.wait<void>(<Future<void>>[
        fetchReviews(),
        fetchSimilarBusinesses(),
        _loadFavoriteStatus(),
      ]);
    } catch (_) {
      _errorMessage = 'Failed to load business details.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBusinessDetails() async {
    final row = await _supabase.getBusinessById(businessId);
    if (row == null) {
      throw StateError('Business not found');
    }

    _business = Business.fromMap(row);
    _services = _parseServices(row['services']);
    _openingHoursText =
        openingHoursSummary(row['opening_hours'] ?? row['openingHours']);
    _foundedText = _parseFounded(row['founded'], row['established']);
  }

  Future<void> fetchReviews() async {
    final rows = await _supabase.listReviews(
      businessId: businessId,
      newestFirst: true,
      limit: 20,
    );

    final userIds = rows
        .map((r) => r['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final usersById = <String, String>{};
    if (userIds.isNotEmpty) {
      final userRows = await _supabase.client
          .from('users')
          .select('id,name')
          .inFilter('id', userIds);
      for (final item in (userRows as List)) {
        final row = Map<String, dynamic>.from(item as Map);
        usersById[row['id']?.toString() ?? ''] = (row['name'] as String?)?.trim() ?? '';
      }
    }

    _reviews = rows.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      final isAnonymous = row['is_anonymous'] as bool? ?? false;
      final name = isAnonymous
          ? 'Anonymous'
          : (usersById[userId]?.isNotEmpty == true ? usersById[userId]! : 'User');
      return BusinessReview(
        id: row['id']?.toString() ?? '',
        userName: name,
        rating: (row['rating'] as num?)?.toDouble() ?? 0,
        comment: row['comment'] as String? ?? '',
        createdAt: _toDate(row['created_at']) ?? DateTime.now(),
        photoUrls: ((row['photos'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .where((url) => url.isNotEmpty)
            .toList(),
      );
    }).toList();
  }

  Future<void> fetchSimilarBusinesses() async {
    if (_business == null) {
      _similarBusinesses = <Business>[];
      return;
    }
    final rows = await _supabase.listBusinesses(
      subcategory: _business!.subcategory,
      limit: 12,
    );
    _similarBusinesses =
        rows.map(Business.fromMap).where((item) => item.id != businessId).toList();
  }

  Future<void> toggleFavoriteStatus() async {
    final userId = _supabase.currentUserId;
    if (userId == null) return;

    if (_isFavorite) {
      await _supabase.removeFavorite(userId: userId, businessId: businessId);
      _isFavorite = false;
    } else {
      await _supabase.addFavorite(userId: userId, businessId: businessId);
      _isFavorite = true;
    }
    notifyListeners();
  }

  Future<void> shareBusiness() async {
    final current = _business;
    if (current == null) return;
    final shareText = StringBuffer()
      ..writeln(current.name)
      ..writeln([
        if (current.mainCategory.isNotEmpty) current.mainCategory,
        if (current.subcategory.isNotEmpty) current.subcategory,
      ].where((e) => e.isNotEmpty).join(' • '))
      ..writeln(current.address)
      ..writeln('Call: ${current.phoneNumber}');
    await Share.share(shareText.toString().trim());
  }

  Future<void> _loadFavoriteStatus() async {
    final userId = _supabase.currentUserId;
    if (userId == null) {
      _isFavorite = false;
      return;
    }
    _isFavorite = await _supabase.isFavorite(userId: userId, businessId: businessId);
  }

  List<BusinessServiceItem> _parseServices(dynamic raw) {
    if (raw is! List) return <BusinessServiceItem>[];
    return raw.map((item) {
      if (item is Map<String, dynamic>) {
        return BusinessServiceItem(
          name: (item['name'] as String?)?.trim() ?? '',
          price: (item['price'] as String?)?.trim() ?? '',
        );
      }
      if (item is Map) {
        return BusinessServiceItem(
          name: (item['name']?.toString() ?? '').trim(),
          price: (item['price']?.toString() ?? '').trim(),
        );
      }
      return const BusinessServiceItem(name: '', price: '');
    }).where((entry) => entry.name.isNotEmpty).toList();
  }

  String? _parseFounded(dynamic founded, dynamic established) {
    final value = founded ?? established;
    if (value == null) return null;
    if (value is DateTime) return value.year.toString();
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }
}
