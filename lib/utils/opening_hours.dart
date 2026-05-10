import 'dart:collection';

const List<String> kOpeningHoursDays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class OpeningHoursDay {
  OpeningHoursDay({
    this.closed = false,
    this.open24Hours = false,
    this.open = '08:00',
    this.close = '18:00',
  });

  bool closed;
  bool open24Hours;
  String open;
  String close;

  String get label {
    if (closed) return 'Closed';
    if (open24Hours) return '24 hours';
    final openValue = open.trim();
    final closeValue = close.trim();
    if (openValue.isEmpty && closeValue.isEmpty) return '';
    if (openValue.isNotEmpty && closeValue.isNotEmpty) {
      return '$openValue - $closeValue';
    }
    return openValue.isNotEmpty ? openValue : closeValue;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'closed': closed,
      'open24Hours': open24Hours,
      'open': open.trim(),
      'close': close.trim(),
      'label': label,
    };
  }

  void reset() {
    closed = false;
    open24Hours = false;
    open = '08:00';
    close = '18:00';
  }

  factory OpeningHoursDay.fromRaw(dynamic raw) {
    if (raw is Map) {
      final map = raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return OpeningHoursDay(
        closed: map['closed'] == true,
        open24Hours: map['open24Hours'] == true,
        open: map['open']?.toString().trim().isNotEmpty == true
            ? map['open'].toString().trim()
            : '08:00',
        close: map['close']?.toString().trim().isNotEmpty == true
            ? map['close'].toString().trim()
            : '18:00',
      );
    }
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      if (value == 'closed') {
        return OpeningHoursDay(closed: true, open: '', close: '');
      }
      if (value == '24 hours') {
        return OpeningHoursDay(open24Hours: true, open: '', close: '');
      }
      final parts = raw.split('-');
      if (parts.length == 2) {
        return OpeningHoursDay(
          open: parts[0].trim(),
          close: parts[1].trim(),
        );
      }
      return OpeningHoursDay(open: raw.trim(), close: '');
    }
    return OpeningHoursDay();
  }
}

LinkedHashMap<String, OpeningHoursDay> buildDefaultOpeningHoursEditorState() {
  return LinkedHashMap<String, OpeningHoursDay>.fromEntries(
    kOpeningHoursDays.map(
      (day) => MapEntry<String, OpeningHoursDay>(day, OpeningHoursDay()),
    ),
  );
}

Map<String, Map<String, dynamic>> buildDefaultOpeningHoursPayload() {
  return <String, Map<String, dynamic>>{
    for (final day in kOpeningHoursDays) day: OpeningHoursDay().toMap(),
  };
}

LinkedHashMap<String, OpeningHoursDay> normalizeOpeningHoursEditorState(
  dynamic raw,
) {
  final normalized = buildDefaultOpeningHoursEditorState();
  if (raw is! Map) {
    return normalized;
  }

  for (final day in kOpeningHoursDays) {
    if (raw.containsKey(day)) {
      normalized[day] = OpeningHoursDay.fromRaw(raw[day]);
    }
  }

  return normalized;
}

Map<String, Map<String, dynamic>> normalizeOpeningHoursPayload(dynamic raw) {
  final normalized = normalizeOpeningHoursEditorState(raw);
  return <String, Map<String, dynamic>>{
    for (final entry in normalized.entries) entry.key: entry.value.toMap(),
  };
}

String? openingHoursLabel(dynamic raw) {
  if (raw is String) {
    return raw.trim().isEmpty ? null : raw.trim();
  }
  if (raw is Map) {
    final day = OpeningHoursDay.fromRaw(raw);
    return day.label.isEmpty ? null : day.label;
  }
  return null;
}

String? openingHoursSummary(dynamic raw) {
  if (raw == null) return null;
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw is! Map) return null;

  final lines = <String>[];
  for (final day in kOpeningHoursDays) {
    final label = openingHoursLabel(raw[day]);
    if (label != null && label.isNotEmpty) {
      lines.add('$day: $label');
    }
  }

  raw.forEach((key, value) {
    final day = key.toString();
    if (kOpeningHoursDays.contains(day)) return;
    final label = openingHoursLabel(value);
    if (label != null && label.isNotEmpty) {
      lines.add('$day: $label');
    }
  });

  if (lines.isEmpty) return null;
  return lines.join('\n');
}
