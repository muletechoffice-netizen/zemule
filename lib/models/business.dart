class Business {
  const Business({
    required this.id,
    required this.name,
    required this.mainCategory,
    required this.subcategory,
    required this.description,
    required this.phoneNumber,
    this.whatsappNumber,
    required this.latitude,
    required this.longitude,
    required this.area,
    this.city = '',
    required this.address,
    required this.photoUrls,
    required this.rating,
    required this.reviewCount,
    required this.isPremium,
    required this.isPromoted,
    this.promotedUntil,
    required this.createdAt,
    this.status = 'approved',
    this.rejectionReason,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String mainCategory;
  final String subcategory;
  final String description;
  final String phoneNumber;
  final String? whatsappNumber;
  final double latitude;
  final double longitude;
  final String area;
  final String city;
  final String address;
  final List<String> photoUrls;
  final double rating;
  final int reviewCount;
  final bool isPremium;
  final bool isPromoted;
  final DateTime? promotedUntil;
  final DateTime createdAt;
  final String status;
  final String? rejectionReason;
  final double? distanceKm;

  // Legacy accessor to avoid touching all UI call sites immediately.
  String get category => subcategory;

  Business copyWith({
    String? id,
    String? name,
    String? mainCategory,
    String? subcategory,
    String? description,
    String? phoneNumber,
    String? whatsappNumber,
    double? latitude,
    double? longitude,
    String? area,
    String? city,
    String? address,
    List<String>? photoUrls,
    double? rating,
    int? reviewCount,
    bool? isPremium,
    bool? isPromoted,
    DateTime? promotedUntil,
    DateTime? createdAt,
    String? status,
    String? rejectionReason,
    double? distanceKm,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      mainCategory: mainCategory ?? this.mainCategory,
      subcategory: subcategory ?? this.subcategory,
      description: description ?? this.description,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      area: area ?? this.area,
      city: city ?? this.city,
      address: address ?? this.address,
      photoUrls: photoUrls ?? this.photoUrls,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isPremium: isPremium ?? this.isPremium,
      isPromoted: isPromoted ?? this.isPromoted,
      promotedUntil: promotedUntil ?? this.promotedUntil,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  factory Business.fromMap(Map<String, dynamic> data) {
    final rawSub = data['subcategory'] ?? data['category'];
    final rawMain = data['main_category'] ?? data['mainCategory'];
    final sub = rawSub is String ? rawSub : '';
    final main = rawMain is String && rawMain.trim().isNotEmpty
        ? rawMain
        : _inferMainCategoryFromSub(sub);

    return Business(
      id: data['id']?.toString() ?? '',
      name: data['name'] as String? ?? '',
      mainCategory: main,
      subcategory: sub,
      description: data['description'] as String? ?? '',
      phoneNumber:
          (data['phone'] as String?) ?? (data['phoneNumber'] as String?) ?? '',
      whatsappNumber: (data['whatsapp'] as String?) ??
          (data['whatsappNumber'] as String?),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      area: data['area'] as String? ?? '',
      city: data['city'] as String? ?? '',
      address: data['address'] as String? ?? '',
      photoUrls: ((data['photos'] as List?) ??
              (data['photoUrls'] as List?) ??
              const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['review_count'] as num?)?.toInt() ??
          (data['reviewCount'] as num?)?.toInt() ??
          0,
      isPremium:
          (data['is_premium'] as bool?) ?? (data['isPremium'] as bool?) ?? false,
      isPromoted: data['isPromoted'] as bool? ?? false,
      promotedUntil: _toDate(data['promoted_until'] ?? data['promotedUntil']),
      createdAt:
          _toDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      status: data['status'] as String? ?? 'approved',
      rejectionReason:
          (data['rejection_reason'] as String?) ?? (data['rejectionReason'] as String?),
      distanceKm: (data['distance_km'] as num?)?.toDouble() ??
          (data['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'main_category': mainCategory,
      'subcategory': subcategory,
      // Keep legacy category for backward compatibility
      'category': subcategory,
      'description': description,
      'phone': phoneNumber,
      'whatsapp': whatsappNumber,
      'latitude': latitude,
      'longitude': longitude,
      'area': area,
      'city': city,
      'address': address,
      'photos': photoUrls,
      'rating': rating,
      'review_count': reviewCount,
      'status': status,
      'is_premium': isPremium,
      'premium_expiry': promotedUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
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

  static String _inferMainCategoryFromSub(String subcategory) {
    final key = subcategory.toLowerCase();
    const mapping = <String, String>{
      'electrician': 'HOME SERVICES',
      'plumber': 'HOME SERVICES',
      'painter': 'HOME SERVICES',
      'carpenter': 'HOME SERVICES',
      'locksmith': 'HOME SERVICES',
      'gardener': 'HOME SERVICES',
      'pool cleaner': 'HOME SERVICES',
      'mechanic': 'AUTO SERVICES',
      'car wash': 'AUTO SERVICES',
      'towing': 'AUTO SERVICES',
      'tire shop': 'AUTO SERVICES',
      'auto electrician': 'AUTO SERVICES',
      'hair salon': 'BEAUTY & CARE',
      'barber': 'BEAUTY & CARE',
      'nail salon': 'BEAUTY & CARE',
      'spa': 'BEAUTY & CARE',
      'makeup artist': 'BEAUTY & CARE',
      'tailor': 'BEAUTY & CARE',
      'laundry': 'BEAUTY & CARE',
      'gym': 'HEALTH & FITNESS',
      'personal trainer': 'HEALTH & FITNESS',
      'doctor': 'HEALTH & FITNESS',
      'pharmacy': 'HEALTH & FITNESS',
      'dentist': 'HEALTH & FITNESS',
      'photographer': 'EVENTS & PHOTOGRAPHY',
      'videographer': 'EVENTS & PHOTOGRAPHY',
      'dj': 'EVENTS & PHOTOGRAPHY',
      'event planner': 'EVENTS & PHOTOGRAPHY',
      'caterer': 'EVENTS & PHOTOGRAPHY',
      'phone repair': 'TECH SERVICES',
      'computer repair': 'TECH SERVICES',
      'web designer': 'TECH SERVICES',
      'graphic designer': 'TECH SERVICES',
      'accountant': 'PROFESSIONAL SERVICES',
      'lawyer': 'PROFESSIONAL SERVICES',
      'real estate agent': 'PROFESSIONAL SERVICES',
      'cleaner': 'PROFESSIONAL SERVICES',
      'gaming station': 'ENTERTAINMENT',
      'gaming': 'ENTERTAINMENT',
      'event venue': 'ENTERTAINMENT',
      'karaoke bar': 'ENTERTAINMENT',
      'tutor': 'EDUCATION',
      'music teacher': 'EDUCATION',
      'computer training': 'EDUCATION',
    };
    for (final entry in mapping.entries) {
      if (key.contains(entry.key)) {
        return entry.value;
      }
    }
    return '';
  }
}
