import 'dart:async';

import 'package:zemule/services/supabase_service.dart';

class AnalyticsService {
  AnalyticsService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  static final Set<String> _trackedCardImpressions = <String>{};

  final SupabaseService _supabase;

  Future<void> trackBusinessView(String businessId, {String? area}) async {
    await _trackInteraction(
      'view',
      businessId,
      area: area,
      counterName: 'views',
    );
  }

  Future<void> trackCallClick(String businessId, {String? area}) async {
    await _trackInteraction(
      'call',
      businessId,
      area: area,
      counterName: 'calls',
    );
  }

  Future<void> trackWhatsAppClick(String businessId, {String? area}) async {
    await _trackInteraction(
      'whatsapp',
      businessId,
      area: area,
      counterName: 'whatsapp_clicks',
    );
  }

  Future<void> trackNewReview(String businessId, {String? area}) async {
    await _trackInteraction('review', businessId, area: area);
  }

  Future<void> trackBusinessCardImpression(
    String businessId, {
    String? area,
  }) async {
    final normalizedId = businessId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    if (!_trackedCardImpressions.add(normalizedId)) {
      return;
    }
    await trackBusinessView(normalizedId, area: area);
  }

  Future<Map<String, int>> calculateTrends(
    String businessId, {
    String period = 'month',
  }) async {
    final now = DateTime.now();
    final currentStart = period == 'week'
        ? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6))
        : DateTime(now.year, now.month, 1);
    final previousStart = period == 'week'
        ? currentStart.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month - 1, 1);
    final previousEnd = period == 'week'
        ? currentStart.subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, 0);

    final currentEnd = now;
    List<Map<String, dynamic>> interactions = <Map<String, dynamic>>[];
    try {
      interactions = await _supabase.listBusinessInteractions(
        businessId: businessId,
        from: previousStart,
        to: currentEnd,
      );
    } catch (_) {
      interactions = <Map<String, dynamic>>[];
    }
    final reviews =
        await _supabase.listReviews(businessId: businessId, newestFirst: true);
    final currentCount = reviews.where((row) {
      final created = _toDate(row['created_at']);
      return created != null && !created.isBefore(currentStart);
    }).length;
    final previousCount = reviews.where((row) {
      final created = _toDate(row['created_at']);
      return created != null &&
          !created.isBefore(previousStart) &&
          !created.isAfter(previousEnd);
    }).length;
    final trend = currentCount.compareTo(previousCount);

    int countInteractions(String type, DateTime from, DateTime to) {
      return interactions.where((row) {
        if ((row['interaction_type']?.toString() ?? '') != type) {
          return false;
        }
        final created = _toDate(row['created_at']);
        return created != null && !created.isBefore(from) && !created.isAfter(to);
      }).length;
    }

    final currentViews = countInteractions('view', currentStart, currentEnd);
    final previousViews = countInteractions('view', previousStart, previousEnd);
    final currentCalls = countInteractions('call', currentStart, currentEnd);
    final previousCalls = countInteractions('call', previousStart, previousEnd);
    final currentWhatsApp =
        countInteractions('whatsapp', currentStart, currentEnd);
    final previousWhatsApp =
        countInteractions('whatsapp', previousStart, previousEnd);

    return <String, int>{
      'views': currentViews,
      'calls': currentCalls,
      'whatsappClicks': currentWhatsApp,
      'newReviews': currentCount,
      'viewsTrend': currentViews.compareTo(previousViews),
      'callsTrend': currentCalls.compareTo(previousCalls),
      'whatsappTrend': currentWhatsApp.compareTo(previousWhatsApp),
      'reviewsTrend': trend,
    };
  }

  Future<List<MapEntry<String, int>>> getTopSearchKeywords(String businessId) async {
    return const <MapEntry<String, int>>[];
  }

  Future<List<MapEntry<String, int>>> getCustomerDemographics(String businessId) async {
    return const <MapEntry<String, int>>[];
  }

  Future<List<MapEntry<int, int>>> getPopularTimes(String businessId) async {
    return const <MapEntry<int, int>>[];
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  Future<void> _trackInteraction(
    String type,
    String businessId, {
    String? area,
    String? counterName,
  }) async {
    try {
      final operations = <Future<void>>[
        _supabase.createBusinessInteraction(<String, dynamic>{
          'business_id': businessId,
          'user_id': _supabase.currentUserId,
          'interaction_type': type,
          'area': area?.trim(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ];
      if (counterName != null && counterName.trim().isNotEmpty) {
        operations.add(
          _supabase.incrementBusinessCounter(
            businessId: businessId,
            counterName: counterName,
          ),
        );
      }
      await Future.wait<void>(operations);
    } catch (_) {
      // Analytics failures should never block the primary user action.
    }
  }
}
