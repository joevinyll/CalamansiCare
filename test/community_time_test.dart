import 'package:flutter_test/flutter_test.dart';
import 'package:calamansi_care/data/community_time.dart';

void main() {
  final created = DateTime.parse('2026-10-23T01:04:05Z');
  test('Relative time uses complete elapsed minutes, hours and days', () {
    for (final entry in {
      const Duration(seconds: 59): 'Just now',
      const Duration(minutes: 1): '1 min ago',
      const Duration(minutes: 59): '59 min ago',
      const Duration(hours: 1): '1 hr ago',
      const Duration(hours: 23): '23 hr ago',
      const Duration(days: 1): '1 day ago',
      const Duration(days: 2): '2 days ago',
    }.entries) {
      expect(
          communityTime(created.toIso8601String(), now: created.add(entry.key))
              .relative,
          entry.value);
    }
  });
  test('Equivalent timezone offsets show the same date and precise local time',
      () {
    final utc = communityTime('2026-10-23T01:04:05Z', now: created);
    final offset = communityTime('2026-10-23T09:04:05+08:00', now: created);
    expect(utc, offset);
    expect(utc.exact, contains('2026'));
    expect(utc.exact, matches(RegExp(r'at \d{1,2}:04(?:am|pm)$')));
    expect(utc.exact, isNot(contains('UTC')));
  });
  test('Time shows hours and minutes with lowercase am or pm', () {
    for (final entry
        in {0: '12:32am', 2: '2:32am', 12: '12:32pm', 14: '2:32pm'}.entries) {
      final local = DateTime(2026, 10, 23, entry.key, 32, 45);
      expect(communityTime(local.toIso8601String(), now: local).exact,
          'Oct 23, 2026 at ${entry.value}');
    }
  });
  test('Invalid timestamps and future device-clock differences are explicit',
      () {
    expect(communityTime(null).relative, 'Time unavailable');
    expect(communityTime('invalid').exact, isEmpty);
    expect(
        communityTime(created.toIso8601String(),
                now: created.subtract(const Duration(hours: 1)))
            .relative,
        'Posted');
  });
}
