// FrontEnd/test/core/design/app_typography_test.dart
//
// Urdu (Nastaliq) and Latin have different metric needs. These tests pin the
// two properties that are easy to regress and that visibly break Urdu:
// the font family, and the generous line height Nastaliq descenders require.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_typography.dart';

void main() {
  group('AppTypography.latin', () {
    test('uses Inter', () {
      expect(AppTypography.latin(size: 14).fontFamily, 'Inter');
    });

    test('passes through size, weight, and height', () {
      final style = AppTypography.latin(size: 18, weight: FontWeight.w600);
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, AppTypography.latinHeight);
    });
  });

  group('AppTypography.mono', () {
    test('uses JetBrainsMono for timecodes', () {
      expect(AppTypography.mono(size: 12).fontFamily, 'JetBrainsMono');
    });
  });

  group('AppTypography.urdu', () {
    test('uses NotoNastaliqUrdu', () {
      expect(AppTypography.urdu(size: 14).fontFamily, 'NotoNastaliqUrdu');
    });

    test('applies the tall line height Nastaliq needs', () {
      expect(AppTypography.urdu(size: 14).height, AppTypography.urduHeight);
      expect(AppTypography.urduHeight, greaterThanOrEqualTo(1.8));
    });

    test('renders optically larger than Latin at the same nominal size', () {
      final latin = AppTypography.latin(size: 14);
      final urdu = AppTypography.urdu(size: 14);
      expect(urdu.fontSize, greaterThan(latin.fontSize!));
    });
  });
}
