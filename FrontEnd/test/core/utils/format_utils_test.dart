// test/core/utils/format_utils_test.dart
//
// Pins the shared project formatters: duration (H:MM:SS / M:SS / --:--) and the
// relative "last edited" date, evaluated against a fixed `now` so the test is
// deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/utils/format_utils.dart';

void main() {
  group('formatDuration', () {
    test('null → em-dash placeholder', () {
      expect(formatDuration(null), '--:--');
    });
    test('under an hour → M:SS', () {
      expect(formatDuration(225), '3:45');
    });
    test('an hour or more → H:MM:SS', () {
      expect(formatDuration(3725), '1:02:05');
    });
  });

  group('formatRelativeDate', () {
    final now = DateTime(2026, 7, 20, 14, 30);
    test('same calendar day → "Today, HH:MM"', () {
      expect(
        formatRelativeDate('2026-07-20T10:24:00', now: now),
        'Today, 10:24',
      );
    });
    test('previous calendar day → "Yesterday"', () {
      expect(formatRelativeDate('2026-07-19T09:00:00', now: now), 'Yesterday');
    });
    test('older → "MMM d, y"', () {
      expect(
        formatRelativeDate('2025-10-12T09:00:00', now: now),
        'Oct 12, 2025',
      );
    });
  });
}
