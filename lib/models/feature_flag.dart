class FeatureFlag {
  const FeatureFlag({
    required this.flagName,
    required this.isEnabled,
    this.updatedAt,
  });

  final String flagName;
  final bool isEnabled;
  final DateTime? updatedAt;

  factory FeatureFlag.fromMap(Map<String, dynamic> data) {
    return FeatureFlag(
      flagName: data['flag_name']?.toString() ?? '',
      isEnabled: data['is_enabled'] as bool? ?? false,
      updatedAt: _toDate(data['updated_at']),
    );
  }

  FeatureFlag copyWith({bool? isEnabled, DateTime? updatedAt}) {
    return FeatureFlag(
      flagName: flagName,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _toDate(dynamic raw) {
    if (raw is DateTime) {
      return raw.toLocal();
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }
}

class FeatureFlagDefinition {
  const FeatureFlagDefinition({
    required this.flagName,
    required this.title,
    required this.description,
    this.defaultValue = false,
  });

  final String flagName;
  final String title;
  final String description;
  final bool defaultValue;
}

const String kShowAnalyticsFlag = 'show_analytics';

const List<FeatureFlagDefinition> kFeatureFlagDefinitions =
    <FeatureFlagDefinition>[
      FeatureFlagDefinition(
        flagName: kShowAnalyticsFlag,
        title: 'Show analytics',
        description:
            'Display the analytics section inside the business dashboard.',
      ),
    ];
