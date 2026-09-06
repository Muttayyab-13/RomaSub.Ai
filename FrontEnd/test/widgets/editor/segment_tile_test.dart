// FrontEnd/test/widgets/editor/segment_tile_test.dart
//
// SegmentTile is one of only two editor widgets with injectable params, so it
// gets real widget tests. Pinned here: the Roman-with-Urdu-fallback caption
// rule, the overlap marker, and the delete affordance — which was a required
// callback that the old tile never rendered.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';
import 'package:romasubai_frontend/widgets/editor/segment_tile.dart';

Widget _host({
  required EditableSegment segment,
  bool isSelected = false,
  bool isActive = false,
  bool matchesSearch = false,
  bool hasOverlap = false,
  VoidCallback? onTap,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    theme: buildEditorTheme(false),
    home: Scaffold(
      body: SegmentTile(
        segment: segment,
        index: 0,
        isSelected: isSelected,
        isActive: isActive,
        matchesSearch: matchesSearch,
        hasOverlap: hasOverlap,
        onTap: onTap ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('shows the 1-based segment number', (tester) async {
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(id: 7, start: 0, end: 2, romanUrduText: 'hi'),
      ),
    );
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows Roman Urdu when present', (tester) async {
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(
          id: 1,
          start: 0,
          end: 2,
          romanUrduText: 'Iski quality aur speed dono behtareen hain.',
          urduText: 'اس کی کوالٹی',
        ),
      ),
    );
    expect(
      find.text('Iski quality aur speed dono behtareen hain.'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to Urdu when Roman is empty', (tester) async {
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(
          id: 1,
          start: 0,
          end: 2,
          romanUrduText: '',
          urduText: 'اس کی کوالٹی',
        ),
      ),
    );
    expect(find.text('اس کی کوالٹی'), findsOneWidget);
  });

  testWidgets('shows the timecode range', (tester) async {
    await tester.pumpWidget(
      _host(segment: EditableSegment(id: 1, start: 72.4, end: 75.2)),
    );
    expect(find.textContaining('00:01:12,400'), findsOneWidget);
    expect(find.textContaining('00:01:15,200'), findsOneWidget);
  });

  testWidgets('marks an edited segment', (tester) async {
    await tester.pumpWidget(
      _host(segment: EditableSegment(id: 1, start: 0, end: 2, isEdited: true)),
    );
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('shows an overlap warning only when overlapping', (tester) async {
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(id: 1, start: 0, end: 2),
        hasOverlap: false,
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await tester.pumpWidget(
      _host(
        segment: EditableSegment(id: 1, start: 0, end: 2),
        hasOverlap: true,
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(id: 1, start: 0, end: 2, romanUrduText: 'hi'),
        onTap: () => tapped = true,
      ),
    );
    await tester.tap(find.text('hi'));
    expect(tapped, isTrue);
  });

  testWidgets('renders a delete affordance when selected and fires onDelete', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      _host(
        segment: EditableSegment(id: 1, start: 0, end: 2),
        isSelected: true,
        onDelete: () => deleted = true,
      ),
    );

    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    expect(deleted, isTrue);
  });
}
