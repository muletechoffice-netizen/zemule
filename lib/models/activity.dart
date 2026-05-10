enum ActivityType { review, favorite, call, view }

class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.businessId,
    required this.businessName,
    required this.timestamp,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final ActivityType type;
  final String businessId;
  final String businessName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
}
