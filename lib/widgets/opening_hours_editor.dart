import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:zemule/utils/opening_hours.dart';

class OpeningHoursEditor extends StatelessWidget {
  const OpeningHoursEditor({
    super.key,
    required this.hoursByDay,
    required this.onChanged,
    this.title = 'Working Hours',
    this.showReset = true,
  });

  final LinkedHashMap<String, OpeningHoursDay> hoursByDay;
  final VoidCallback onChanged;
  final String title;
  final bool showReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (showReset)
                  TextButton(
                    onPressed: () {
                      for (final hours in hoursByDay.values) {
                        hours.reset();
                      }
                      onChanged();
                    },
                    child: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...hoursByDay.entries.map(
              (entry) => _OpeningHoursDayRow(
                day: entry.key,
                hours: entry.value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningHoursDayRow extends StatelessWidget {
  const _OpeningHoursDayRow({
    required this.day,
    required this.hours,
    required this.onChanged,
  });

  final String day;
  final OpeningHoursDay hours;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isClosed = hours.closed;
    final is24 = hours.open24Hours;
    final showTimes = !isClosed && !is24;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: !isClosed,
                onChanged: (value) {
                  hours.closed = !value;
                  if (hours.closed) {
                    hours.open24Hours = false;
                  }
                  onChanged();
                },
              ),
              const SizedBox(width: 6),
              Text(isClosed ? 'Closed' : 'Open'),
            ],
          ),
          if (!isClosed) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: const Text('Custom'),
                  selected: !is24,
                  onSelected: (_) {
                    hours.open24Hours = false;
                    hours.closed = false;
                    onChanged();
                  },
                ),
                FilterChip(
                  label: const Text('24 hours'),
                  selected: is24,
                  onSelected: (selected) {
                    hours.open24Hours = selected;
                    if (selected) {
                      hours.closed = false;
                    }
                    onChanged();
                  },
                ),
                FilterChip(
                  label: const Text('Closed'),
                  selected: isClosed,
                  onSelected: (selected) {
                    hours.closed = selected;
                    if (selected) {
                      hours.open24Hours = false;
                    }
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showTimes)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(context, isOpenTime: true),
                      icon: const Icon(Icons.access_time),
                      label: Text('Opens: ${hours.open}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(context, isOpenTime: false),
                      icon: const Icon(Icons.schedule),
                      label: Text('Closes: ${hours.close}'),
                    ),
                  ),
                ],
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hours.label.isEmpty ? 'Set hours for this day' : hours.label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context, {
    required bool isOpenTime,
  }) async {
    final initialText = isOpenTime ? hours.open : hours.close;
    final initialTime =
        _parseTimeOfDay(initialText) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) {
      return;
    }

    hours.closed = false;
    hours.open24Hours = false;
    final formatted = _formatTime(picked);
    if (isOpenTime) {
      hours.open = formatted;
    } else {
      hours.close = formatted;
    }
    onChanged();
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
