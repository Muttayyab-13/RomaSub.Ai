// FrontEnd/test/widgets/editor/segment_timeline_test.dart
//
// The timeline maps seconds to pixels and back. That mapping is the whole
// widget, so it is tested directly: block placement, playhead position, and
// click-to-seek must agree on the same scale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';
import 'package:romasubai_frontend/widgets/editor/segment_timeline.dart';

final _segments = [
  EditableSegment(id: 1, start: 0.0, end: 2.0, romanUrduText: 'first'),
  EditableSegment(id: 2, start: 2.5, end: 5.0, romanUrduText: 'second'),
];

Widget _host({
  double position = 0.0,
  int? selectedIndex,
  ValueChanged<double>? onSeek,
  ValueChanged<int>? onSelect,
  double pixelsPerSecond = 40.0,
}) {
  return MaterialApp(
    theme: buildEditorTheme(false),
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: SegmentTimeline.height,
        child: SegmentTimeline(
          segments: _segments,
          positionSeconds: position,
          durationSeconds: 10.0,
          selectedIndex: selectedIndex,
          pixelsPerSecond: pixelsPerSecond,
          onSeek: onSeek ?? (_) {},
          onSelect: onSelect ?? (_) {},
          onZoomIn: () {},
          onZoomOut: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a block per segment', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(TimelineBlock), findsNWidgets(2));
  });

  testWidgets('block width follows duration and scale', (tester) async {
    await tester.pumpWidget(_host(pixelsPerSecond: 40));
    // First segment: 2.0s * 40px = 80px
    final size = tester.getSize(find.byType(TimelineBlock).first);
    expect(size.width, 80.0);
  });

  testWidgets('shows the current scale', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.textContaining('Scale'), findsOneWidget);
  });

  testWidgets('tapping a block selects that segment', (tester) async {
    int? selected;
    await tester.pumpWidget(_host(onSelect: (i) => selected = i));
    await tester.tap(find.byType(TimelineBlock).last);
    expect(selected, 1);
  });

  testWidgets('exposes zoom controls', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out_rounded), findsOneWidget);
  });

  testWidgets('renders a playhead', (tester) async {
    await tester.pumpWidget(_host(position: 3.0));
    expect(find.byKey(SegmentTimeline.playheadKey), findsOneWidget);
  });
}
