class Review {
  const Review({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.photoUrls,
    required this.isAnonymous,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final List<String> photoUrls;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Review.fromMap(Map<String, dynamic> data) {
    return Review(
      id: data['id']?.toString() ?? '',
      businessId:
          (data['business_id'] as String?) ?? (data['businessId'] as String?) ?? '',
      userId: (data['user_id'] as String?) ?? (data['userId'] as String?) ?? '',
      userName:
          (data['user_name'] as String?) ?? (data['userName'] as String?) ?? 'Anonymous',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment'] as String? ?? '',
      photoUrls: ((data['photos'] as List?) ??
              (data['photoUrls'] as List?) ??
              const <dynamic>[])
          .map((e) => e.toString())
          .where((url) => url.isNotEmpty)
          .toList(),
      isAnonymous: (data['is_anonymous'] as bool?) ??
          (data['isAnonymous'] as bool?) ??
          false,
      createdAt:
          _toDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(data['updated_at'] ?? data['updatedAt']) ??
          _toDate(data['created_at'] ?? data['createdAt']) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'business_id': businessId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'photos': photoUrls,
      'is_anonymous': isAnonymous,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime? _toDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }
}
