import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentAuthUser => client.auth.currentUser;

  String? get currentUserId => currentAuthUser?.id;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signOut() => client.auth.signOut();

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    required String redirectTo,
  }) {
    return client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updateAuthUser({
    String? email,
    String? password,
    Map<String, dynamic>? data,
  }) {
    return client.auth.updateUser(
      UserAttributes(email: email, password: password, data: data),
    );
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final rows = await client.from('users').select().eq('id', userId).limit(1);
    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }

  Future<void> upsertUser(Map<String, dynamic> data) {
    return client.from('users').upsert(data);
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = currentAuthUser;
    if (user == null) {
      return false;
    }

    final row = await getUserById(user.id);
    return row?['is_admin'] == true;
  }

  Future<void> insertLoginAttempt({
    required String email,
    required bool success,
  }) {
    return client.from('login_attempts').insert(<String, dynamic>{
      'email': email.trim().toLowerCase(),
      'success': success,
    });
  }

  Future<List<Map<String, dynamic>>> listBusinesses({
    String? ownerId,
    String? category,
    String? mainCategory,
    String? subcategory,
    String? areaOrCity,
    String? status,
    bool newestFirst = true,
    int? limit,
  }) async {
    dynamic query = client.from('businesses').select();
    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.eq('owner_id', ownerId);
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (mainCategory != null && mainCategory.isNotEmpty) {
      query = query.eq('main_category', mainCategory);
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      query = query.eq('subcategory', subcategory);
    }
    if (areaOrCity != null && areaOrCity.trim().isNotEmpty) {
      final value = _buildIlikePattern(areaOrCity.trim());
      query = query.or('area.ilike.$value,city.ilike.$value');
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    query = query.order('created_at', ascending: !newestFirst);
    if (limit != null) {
      query = query.limit(limit);
    }
    final rows = await query;
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listNearbyBusinesses({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String status = 'approved',
  }) async {
    final rows = await client.rpc(
      'get_nearby_businesses',
      params: <String, dynamic>{
        'user_lat': latitude,
        'user_lng': longitude,
        'radius_km': _normalizeRadiusKm(radiusKm),
        'status_filter': status,
      },
    );

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> getBusinessById(String id) async {
    final rows = await client.from('businesses').select().eq('id', id).limit(1);
    if (rows.isNotEmpty) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>> createBusiness(
    Map<String, dynamic> payload,
  ) async {
    final normalizedPayload = <String, dynamic>{...payload};
    final status = normalizedPayload['status']?.toString().trim() ?? '';
    if (status.isEmpty) {
      normalizedPayload['status'] = 'pending';
    }
    final rows = await client
        .from('businesses')
        .insert(normalizedPayload)
        .select()
        .limit(1);
    return Map<String, dynamic>.from((rows as List).first as Map);
  }

  Future<void> updateBusiness(String id, Map<String, dynamic> payload) {
    return client.from('businesses').update(payload).eq('id', id);
  }

  Future<void> refreshBusinessRating(String businessId) async {
    final reviews = await listReviews(businessId: businessId);
    final totalCount = reviews.length;
    final totalRating = reviews.fold<double>(0, (acc, row) {
      return acc + ((row['rating'] as num?)?.toDouble() ?? 0);
    });
    final averageRating = totalCount == 0 ? 0 : totalRating / totalCount;

    await updateBusiness(businessId, <String, dynamic>{
      'rating': averageRating,
      'review_count': totalCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> listReviews({
    String? businessId,
    String? userId,
    bool newestFirst = true,
    int? limit,
  }) async {
    dynamic query = client.from('reviews').select();
    if (businessId != null && businessId.isNotEmpty) {
      query = query.eq('business_id', businessId);
    }
    if (userId != null && userId.isNotEmpty) {
      query = query.eq('user_id', userId);
    }
    query = query.order('created_at', ascending: !newestFirst);
    if (limit != null) {
      query = query.limit(limit);
    }
    final rows = await query;
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createReview(
    Map<String, dynamic> payload,
  ) async {
    final rows = await client.from('reviews').insert(payload).select().limit(1);
    return Map<String, dynamic>.from((rows as List).first as Map);
  }

  Future<void> updateReview(String id, Map<String, dynamic> payload) {
    return client.from('reviews').update(payload).eq('id', id);
  }

  Future<void> deleteReview(String id) {
    return client.from('reviews').delete().eq('id', id);
  }

  Future<void> createBusinessInteraction(Map<String, dynamic> payload) {
    return client.from('business_interactions').insert(payload);
  }

  Future<void> incrementBusinessCounter({
    required String businessId,
    required String counterName,
    int amount = 1,
  }) {
    return client.rpc(
      'increment_business_counter',
      params: <String, dynamic>{
        'target_business_id': businessId,
        'counter_name': counterName,
        'increment_by': amount,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listBusinessInteractions({
    String? businessId,
    String? interactionType,
    DateTime? from,
    DateTime? to,
  }) async {
    dynamic query = client.from('business_interactions').select();
    if (businessId != null && businessId.isNotEmpty) {
      query = query.eq('business_id', businessId);
    }
    if (interactionType != null && interactionType.isNotEmpty) {
      query = query.eq('interaction_type', interactionType);
    }
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('created_at', to.toUtc().toIso8601String());
    }
    query = query.order('created_at', ascending: false);
    final rows = await query;
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listFavorites(String userId) async {
    final rows = await client
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> addFavorite({
    required String userId,
    required String businessId,
  }) {
    return client.from('favorites').upsert(<String, dynamic>{
      'user_id': userId,
      'business_id': businessId,
    });
  }

  Future<void> removeFavorite({
    required String userId,
    required String businessId,
  }) {
    return client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('business_id', businessId);
  }

  Future<bool> isFavorite({
    required String userId,
    required String businessId,
  }) async {
    final rows = await client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('business_id', businessId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
    bool upsert = true,
  }) async {
    await client.storage
        .from(bucket)
        .upload(path, file, fileOptions: FileOptions(upsert: upsert));
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> removeFiles({
    required String bucket,
    required List<String> paths,
  }) {
    if (paths.isEmpty) {
      return Future<void>.value();
    }
    return client.storage.from(bucket).remove(paths);
  }

  Future<List<Map<String, dynamic>>> listFeatureFlags() async {
    final rows = await client
        .from('feature_flags')
        .select()
        .order('flag_name', ascending: true);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> upsertFeatureFlag({
    required String flagName,
    required bool isEnabled,
  }) {
    return client.from('feature_flags').upsert(<String, dynamic>{
      'flag_name': flagName.trim(),
      'is_enabled': isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> processPayment({
    required String phoneNumber,
    required num amount,
    required String paymentMethod,
  }) async {
    final response = await client.functions.invoke(
      'process-payment',
      body: <String, dynamic>{
        'phoneNumber': phoneNumber.trim(),
        'amount': amount,
        'paymentMethod': paymentMethod.trim(),
      },
    );

    final payload = _normalizeFunctionPayload(response.data);
    final success = payload['success'] == true;
    if (!success) {
      final message = payload['message']?.toString().trim();
      throw message != null && message.isNotEmpty
          ? message
          : 'Payment request failed. Please try again.';
    }

    return payload;
  }

  Map<String, dynamic> _normalizeFunctionPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return <String, dynamic>{'message': data};
      }
    }

    return <String, dynamic>{'message': 'Unexpected function response.'};
  }

  double _normalizeRadiusKm(double value) {
    if (!value.isFinite) {
      return 5;
    }
    return value.clamp(5, 20).toDouble();
  }

  String _buildIlikePattern(String value) {
    final escaped = value
        .replaceAll(',', r'\,')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }
}
