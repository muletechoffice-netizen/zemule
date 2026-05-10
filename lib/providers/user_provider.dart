import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:zemule/models/activity.dart';
import 'package:zemule/models/business.dart';
import 'package:zemule/models/review.dart';
import 'package:zemule/services/supabase_service.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.memberSince,
    required this.isBusinessOwner,
    this.businessId,
    this.businessName,
    this.businessPhotoUrl,
    this.last7DaysViews = 0,
    this.last7DaysCalls = 0,
  });

  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final DateTime memberSince;
  final bool isBusinessOwner;
  final String? businessId;
  final String? businessName;
  final String? businessPhotoUrl;
  final int last7DaysViews;
  final int last7DaysCalls;

  factory UserProfile.fromMap(
    Map<String, dynamic> data, {
    Business? ownedBusiness,
  }) {
    return UserProfile(
      id: data['id']?.toString() ?? '',
      name: (data['name'] as String? ?? '').trim(),
      email: (data['email'] as String?)?.trim().isEmpty == true ? null : (data['email'] as String?),
      photoUrl: (data['avatar_url'] as String?)?.trim().isEmpty == true
          ? null
          : (data['avatar_url'] as String?),
      memberSince: _toDate(data['created_at']) ?? DateTime.now(),
      isBusinessOwner: ownedBusiness != null,
      businessId: ownedBusiness?.id,
      businessName: ownedBusiness?.name,
      businessPhotoUrl: ownedBusiness?.photoUrls.isNotEmpty == true
          ? ownedBusiness!.photoUrls.first
          : null,
      last7DaysViews: 0,
      last7DaysCalls: 0,
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      memberSince: memberSince,
      isBusinessOwner: isBusinessOwner,
      businessId: businessId,
      businessName: businessName,
      businessPhotoUrl: businessPhotoUrl,
      last7DaysViews: last7DaysViews,
      last7DaysCalls: last7DaysCalls,
    );
  }

  static DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }
}

class UserProvider extends ChangeNotifier {
  UserProvider({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  final SupabaseService _supabase;

  UserProfile? _user;
  List<Review> _myReviews = <Review>[];
  List<Business> _myFavorites = <Business>[];
  List<Activity> _recentActivity = <Activity>[];
  bool _isLoading = false;
  String? _error;

  final Map<String, String> _businessNames = <String, String>{};
  final Map<String, String> _businessPhotos = <String, String>{};

  UserProfile? get user => _user;
  List<Review> get myReviews => _myReviews;
  List<Business> get myFavorites => _myFavorites;
  List<Activity> get recentActivity => _recentActivity;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String businessNameFor(String businessId) => _businessNames[businessId] ?? 'Business';
  String? businessPhotoFor(String businessId) => _businessPhotos[businessId];

  Future<void> loadUserProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final row = await _supabase.getUserById(userId);
      final businesses = await _supabase.listBusinesses(ownerId: userId, limit: 1);
      final ownedBusiness = businesses.isNotEmpty ? Business.fromMap(businesses.first) : null;

      if (row == null) {
        final authUser = _supabase.currentAuthUser;
        final profile = <String, dynamic>{
          'id': userId,
          'email': authUser?.email,
          'name': (authUser?.userMetadata?['name'] as String?) ?? '',
          'avatar_url': (authUser?.userMetadata?['avatar_url'] as String?) ?? '',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _supabase.upsertUser(profile);
        _user = UserProfile.fromMap(profile, ownedBusiness: ownedBusiness);
      } else {
        _user = UserProfile.fromMap(row, ownedBusiness: ownedBusiness);
      }
    } catch (_) {
      _error = 'Failed to load profile.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(String name, File? photo) async {
    final currentUser = _supabase.currentAuthUser;
    if (currentUser == null) {
      throw const FormatException('You must be signed in to update your profile.');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? photoUrl = _user?.photoUrl;
      if (photo != null) {
        final path = '${currentUser.id}/profile.jpg';
        photoUrl = await _supabase.uploadFile(bucket: 'avatars', path: path, file: photo);
      }

      await _supabase.upsertUser(<String, dynamic>{
        'id': currentUser.id,
        'name': name.trim(),
        'avatar_url': photoUrl,
      });

      _user = (_user ??
              UserProfile(
                id: currentUser.id,
                name: name.trim(),
                email: currentUser.email,
                photoUrl: photoUrl,
                memberSince: DateTime.now(),
                isBusinessOwner: false,
              ))
          .copyWith(name: name.trim(), photoUrl: photoUrl);
    } on FormatException {
      rethrow;
    } catch (_) {
      _error = 'Failed to update profile. Please try again.';
      throw const FormatException('Failed to update profile. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmail(String? email) async {
    final currentUser = _supabase.currentAuthUser;
    if (currentUser == null) {
      throw const FormatException('You must be signed in to update your email.');
    }

    try {
      final trimmed = (email ?? '').trim();
      await _supabase.upsertUser(<String, dynamic>{
        'id': currentUser.id,
        'email': trimmed,
      });
      _user = _user?.copyWith(email: trimmed.isEmpty ? null : trimmed);
      notifyListeners();
    } catch (_) {
      _error = 'Failed to update email.';
      notifyListeners();
      throw const FormatException('Failed to update email. Please try again.');
    }
  }

  Future<void> createUserProfileOnSignUp({
    required String uid,
    String? email,
    required String name,
  }) async {
    try {
      await _supabase.upsertUser(<String, dynamic>{
        'id': uid,
        'email': (email ?? '').trim(),
        'name': name.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'last_login': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      _error = 'Failed to create profile.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateLastLogin({
    required String uid,
    String? email,
    String? name,
  }) async {
    try {
      final updates = <String, dynamic>{
        'id': uid,
        'last_login': DateTime.now().toUtc().toIso8601String(),
      };
      if ((email ?? '').trim().isNotEmpty) updates['email'] = email!.trim();
      if ((name ?? '').trim().isNotEmpty) updates['name'] = name!.trim();
      await _supabase.upsertUser(updates);
    } catch (_) {
      _error = 'Failed to update last login.';
      notifyListeners();
    }
  }

  Future<void> loadMyReviews(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase.listReviews(userId: userId, newestFirst: true);
      final userName = (_user?.name.isNotEmpty == true) ? _user!.name : 'User';
      _myReviews = rows
          .map((row) => Review.fromMap(<String, dynamic>{...row, 'user_name': userName}))
          .toList();
      await _cacheBusinessDetails(_myReviews.map((r) => r.businessId).toSet());
    } catch (_) {
      _error = 'Failed to load reviews.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyFavorites(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final favorites = await _supabase.listFavorites(userId);
      final favoriteIds = favorites
          .map((row) => row['business_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final loaded = <Business>[];
      if (favoriteIds.isNotEmpty) {
        final rows = await _supabase.client
            .from('businesses')
            .select()
            .inFilter('id', favoriteIds);
        for (final item in (rows as List)) {
          final business = Business.fromMap(Map<String, dynamic>.from(item as Map));
          loaded.add(business);
          _businessNames[business.id] = business.name;
          if (business.photoUrls.isNotEmpty) {
            _businessPhotos[business.id] = business.photoUrls.first;
          }
        }
      }
      _myFavorites = loaded;
    } catch (_) {
      _error = 'Failed to load favorites.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecentActivity(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reviews = await _supabase.listReviews(userId: userId, newestFirst: true, limit: 10);
      final favorites = await _supabase.listFavorites(userId);

      final reviewActivities = reviews.map((r) {
        final businessId = r['business_id']?.toString() ?? '';
        return Activity(
          id: r['id']?.toString() ?? '',
          type: ActivityType.review,
          businessId: businessId,
          businessName: _businessNames[businessId] ?? 'Business',
          timestamp: _toDate(r['created_at']) ?? DateTime.now(),
        );
      });
      final favoriteActivities = favorites.take(10).map((f) {
        final businessId = f['business_id']?.toString() ?? '';
        return Activity(
          id: f['id']?.toString() ?? '',
          type: ActivityType.favorite,
          businessId: businessId,
          businessName: _businessNames[businessId] ?? 'Business',
          timestamp: _toDate(f['created_at']) ?? DateTime.now(),
        );
      });

      _recentActivity = <Activity>[...reviewActivities, ...favoriteActivities]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (_recentActivity.length > 20) {
        _recentActivity = _recentActivity.take(20).toList();
      }
    } catch (_) {
      _error = 'Failed to load activity.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateReview(
    String reviewId, {
    required int rating,
    required String comment,
  }) async {
    try {
      final existingReview = _myReviews.cast<Review?>().firstWhere(
            (review) => review?.id == reviewId,
            orElse: () => null,
          );
      await _supabase.updateReview(reviewId, <String, dynamic>{
        'rating': rating,
        'comment': comment.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (existingReview != null) {
        await _supabase.refreshBusinessRating(existingReview.businessId);
      }

      final index = _myReviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        final old = _myReviews[index];
        _myReviews[index] = Review(
          id: old.id,
          businessId: old.businessId,
          userId: old.userId,
          userName: old.userName,
          rating: rating,
          comment: comment.trim(),
          photoUrls: old.photoUrls,
          isAnonymous: old.isAnonymous,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (_) {
      _error = 'Failed to update review.';
      notifyListeners();
    }
  }

  Future<void> deleteReview(String reviewId) async {
    try {
      final existingReview = _myReviews.cast<Review?>().firstWhere(
            (review) => review?.id == reviewId,
            orElse: () => null,
          );
      await _supabase.deleteReview(reviewId);
      if (existingReview != null) {
        await _supabase.refreshBusinessRating(existingReview.businessId);
      }
      _myReviews = _myReviews.where((review) => review.id != reviewId).toList();
      notifyListeners();
    } catch (_) {
      _error = 'Failed to delete review.';
      notifyListeners();
    }
  }

  Future<void> removeFavorite(String businessId) async {
    final currentUser = _supabase.currentAuthUser;
    if (currentUser == null) return;

    try {
      await _supabase.removeFavorite(userId: currentUser.id, businessId: businessId);
      _myFavorites = _myFavorites.where((item) => item.id != businessId).toList();
      notifyListeners();
    } catch (_) {
      _error = 'Failed to remove favorite.';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _supabase.signOut();
    clearUserData();
  }

  void clearUserData() {
    _user = null;
    _myReviews = <Review>[];
    _myFavorites = <Business>[];
    _recentActivity = <Activity>[];
    _error = null;
    _businessNames.clear();
    _businessPhotos.clear();
    notifyListeners();
  }

  Future<void> loadAll(String userId) async {
    await loadUserProfile(userId);
    await Future.wait<void>(<Future<void>>[
      loadMyReviews(userId),
      loadMyFavorites(userId),
      loadRecentActivity(userId),
    ]);
  }

  Future<void> _cacheBusinessDetails(Set<String> businessIds) async {
    for (final id in businessIds) {
      if (_businessNames.containsKey(id) && _businessPhotos.containsKey(id)) {
        continue;
      }
      final row = await _supabase.getBusinessById(id);
      if (row == null) continue;
      final business = Business.fromMap(row);
      _businessNames[id] = business.name;
      if (business.photoUrls.isNotEmpty) {
        _businessPhotos[id] = business.photoUrls.first;
      }
    }
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }
}
