// lib/core/utils/format_utils.dart
import 'package:intl/intl.dart';

/// Formats a seconds count as H:MM:SS (≥1h) or M:SS, or "--:--" when null.
String formatDuration(num? seconds) {
  if (seconds == null) return '--:--';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Relative "last edited" label from an ISO-8601 string.
/// Same day → "Today, HH:MM"; previous day → "Yesterday"; else "MMM d, y".
/// [now] is injectable for deterministic tests.
String formatRelativeDate(String iso, {DateTime? now}) {
  final when = DateTime.tryParse(iso)?.toLocal();
  if (when == null) return '';
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final thatDay = DateTime(when.year, when.month, when.day);
  final diff = today.difference(thatDay).inDays;
  if (diff == 0) return 'Today, ${DateFormat('HH:mm').format(when)}';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d, y').format(when);
}
