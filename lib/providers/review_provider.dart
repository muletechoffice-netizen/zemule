import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:zemule/services/analytics_service.dart';
import 'package:zemule/services/supabase_service.dart';

class ReviewProvider extends ChangeNotifier {
  static const int _maxReviewPhotos = 3;
  static const int _maxPhotoBytes = 5 * 1024 * 1024;

  ReviewProvider({SupabaseService? supabase, AnalyticsService? analyticsService})
      : _supabase = supabase ?? SupabaseService.instance,
        _analyticsService = analyticsService ?? AnalyticsService();

  final SupabaseService _supabase;
  final AnalyticsService _analyticsService;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> submitReview({
    required String businessId,
    required int rating,
    String? comment,
    List<File>? photos,
    bool isAnonymous = false,
  }) async {
    if (rating < 1 || rating > 5) {
      _error = 'Please select a valid rating.';
      notifyListeners();
      return false;
    }

    final user = _supabase.currentAuthUser;
    if (user == null) {
      _error = 'Please sign in to submit a review.';
      notifyListeners();
      return false;
    }

    final selectedPhotos = photos ?? <File>[];
    if (selectedPhotos.length > _maxReviewPhotos) {
      _error = 'You can upload up to $_maxReviewPhotos review photos.';
      notifyListeners();
      return false;
    }
    final photoValidationError = await _validatePhotos(selectedPhotos);
    if (photoValidationError != null) {
      _error = photoValidationError;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final created = await _supabase.createReview(<String, dynamic>{
        'business_id': businessId,
        'user_id': user.id,
        'rating': rating,
        'comment': (comment ?? '').trim(),
        'photos': <String>[],
        'is_anonymous': isAnonymous,
        'created_at': now,
      });

      final reviewId = created['id']?.toString() ?? '';
      if (reviewId.isEmpty) {
        throw StateError('Review id missing');
      }

      if (selectedPhotos.isNotEmpty) {
        final urls = await uploadPhotos(selectedPhotos, reviewId);
        await _updateReviewPhotoUrls(reviewId, urls);
      }

      await _recalculateBusinessStats(businessId);
      await _analyticsService.trackNewReview(businessId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Failed to submit review. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<String>> uploadPhotos(List<File> photos, String reviewId) async {
    final urls = <String>[];
    for (int i = 0; i < photos.length; i++) {
      final path = '$reviewId/photo${i + 1}.jpg';
      final downloadUrl = await _supabase.uploadFile(
        bucket: 'reviews',
        path: path,
        file: photos[i],
      );
      urls.add(downloadUrl);
    }
    return urls;
  }

  Future<void> updateReview(
    String reviewId, {
    int? rating,
    String? comment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase.client
          .from('reviews')
          .select('id,business_id')
          .eq('id', reviewId)
          .limit(1);
      if (rows.isEmpty) {
        throw StateError('Review not found');
      }
      final businessId = (rows.first as Map)['business_id']?.toString() ?? '';
      if (businessId.isEmpty) {
        throw StateError('Invalid review');
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (rating != null) updates['rating'] = rating;
      if (comment != null) updates['comment'] = comment.trim();

      await _supabase.updateReview(reviewId, updates);
      await _recalculateBusinessStats(businessId);

      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _error = 'Failed to update review.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteReview(String reviewId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await _supabase.client.from('reviews').select().eq('id', reviewId).limit(1);
      if (rows.isEmpty) {
        throw StateError('Review not found');
      }
      final data = Map<String, dynamic>.from(rows.first as Map);
      final businessId = data['business_id']?.toString() ?? '';
      final photoUrls = ((data['photos'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList();

      await _supabase.deleteReview(reviewId);

      final paths = photoUrls.map(_extractStoragePath).whereType<String>().toList();
      if (paths.isNotEmpty) {
        await _supabase.removeFiles(bucket: 'reviews', paths: paths);
      }
      await _recalculateBusinessStats(businessId);

      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _error = 'Failed to delete review.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateReviewPhotoUrls(String reviewId, List<String> photoUrls) async {
    await _supabase.updateReview(reviewId, <String, dynamic>{
      'photos': photoUrls,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _recalculateBusinessStats(String businessId) async {
    await _supabase.refreshBusinessRating(businessId);
  }

  String? _extractStoragePath(String url) {
    final marker = '/object/public/reviews/';
    final idx = url.indexOf(marker);
    if (idx == -1) {
      return null;
    }
    return url.substring(idx + marker.length);
  }

  Future<String?> _validatePhotos(List<File> photos) async {
    for (final file in photos) {
      final exists = await file.exists();
      if (!exists) {
        return 'One selected photo is unavailable. Please choose it again.';
      }
      final lengthBytes = await file.length();
      if (lengthBytes <= 0) {
        return 'One selected photo is empty. Please choose another file.';
      }
      if (lengthBytes > _maxPhotoBytes) {
        final sizeMb = (lengthBytes / (1024 * 1024)).toStringAsFixed(1);
        return 'Review photo is too large ($sizeMb MB). Max size is 5MB.';
      }
    }
    return null;
  }
}
