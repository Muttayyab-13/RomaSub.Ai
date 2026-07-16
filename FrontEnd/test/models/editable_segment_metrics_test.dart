// FrontEnd/test/models/editable_segment_metrics_test.dart
//
// CPS drives the editor's legibility readout, and overlap detection drives the
// warning icon in the segment list. Both are computed client-side from data we
// already hold, so they are pure and worth pinning precisely.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

EditableSegment _seg({
  int id = 1,
  double start = 0.0,
  double end = 2.0,
  String roman = '',
  String urdu = '',
}) {
  return EditableSegment(
    id: id,
    start: start,
    end: end,
    romanUrduText: roman,
    urduText: urdu,
  );
}

void main() {
  group('charsPerSecond', () {
    test('divides Roman Urdu length by duration', () {
      // 43 chars over 2.0s = 21.5
      final s = _seg(start: 0, end: 2, roman: 'a' * 43);
      expect(s.charsPerSecond, 21.5);
    });

    test('falls back to Urdu text when Roman is empty', () {
      final s = _seg(start: 0, end: 2, urdu: 'ا' * 10);
      expect(s.charsPerSecond, 5.0);
    });

    test('is zero for empty text', () {
      expect(_seg(roman: '').charsPerSecond, 0.0);
    });

    test('is zero rather than infinite for zero duration', () {
      final s = _seg(start: 5, end: 5, roman: 'hello');
      expect(s.charsPerSecond, 0.0);
    });
  });

  group('isComfortableReadingRate', () {
    test('accepts a normal rate', () {
      expect(_seg(start: 0, end: 4, roman: 'a' * 40).isComfortableReadingRate,
          isTrue);
    });

    test('rejects a rate above the threshold', () {
      expect(_seg(start: 0, end: 1, roman: 'a' * 40).isComfortableReadingRate,
          isFalse);
    });
  });

  group('overlapsNext', () {
    test('is false when the gap meets the minimum', () {
      final a = _seg(id: 1, start: 0.0, end: 2.0);
      final b = _seg(id: 2, start: 2.1, end: 4.0);
      expect(a.overlapsNext(b), isFalse);
    });

    test('is true when the next segment starts too soon', () {
      final a = _seg(id: 1, start: 0.0, end: 2.0);
      final b = _seg(id: 2, start: 2.05, end: 4.0);
      expect(a.overlapsNext(b), isTrue);
    });

    test('is true when segments genuinely overlap', () {
      final a = _seg(id: 1, start: 0.0, end: 3.0);
      final b = _seg(id: 2, start: 2.0, end: 4.0);
      expect(a.overlapsNext(b), isTrue);
    });

    test('is false against a null next segment', () {
      expect(_seg().overlapsNext(null), isFalse);
    });
  });
}
