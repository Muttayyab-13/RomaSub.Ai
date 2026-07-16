// FrontEnd/test/models/subtitle_project_copywith_test.dart
//
// EditorNotifier rebuilt SubtitleProject by hand in three places (undo, redo,
// fixTimingOverlaps). copyWith replaces that duplication, so it must preserve
// every field it isn't asked to change — including the nullable fileDuration.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

SubtitleProject _project({
  List<EditableSegment>? segments,
  double? fileDuration = 120.0,
}) {
  return SubtitleProject(
    subtitleId: 'sub-1',
    fileId: 'file-1',
    projectName: 'Documentary_Ep1_Draft',
    originalFilename: 'Documentary_Ep1_Draft.mp4',
    isVideo: true,
    segments: segments ?? [EditableSegment(id: 1, start: 0, end: 2)],
    segmentCount: segments?.length ?? 1,
    fileDuration: fileDuration,
    createdAt: '2026-07-16T10:00:00Z',
    updatedAt: '2026-07-16T10:00:00Z',
  );
}

void main() {
  test('copyWith preserves every untouched field', () {
    final original = _project();
    final copy = original.copyWith();

    expect(copy.subtitleId, original.subtitleId);
    expect(copy.fileId, original.fileId);
    expect(copy.projectName, original.projectName);
    expect(copy.originalFilename, original.originalFilename);
    expect(copy.isVideo, original.isVideo);
    expect(copy.segments, original.segments);
    expect(copy.segmentCount, original.segmentCount);
    expect(copy.fileDuration, original.fileDuration);
    expect(copy.createdAt, original.createdAt);
    expect(copy.updatedAt, original.updatedAt);
  });

  test('copyWith replaces segments and segmentCount together', () {
    final original = _project();
    final segments = [
      EditableSegment(id: 1, start: 0, end: 2),
      EditableSegment(id: 2, start: 2.5, end: 4),
    ];
    final copy = original.copyWith(
      segments: segments,
      segmentCount: segments.length,
    );

    expect(copy.segments, hasLength(2));
    expect(copy.segmentCount, 2);
    expect(copy.projectName, original.projectName);
  });

  test('copyWith keeps a null fileDuration null', () {
    final original = _project(fileDuration: null);
    expect(original.copyWith().fileDuration, isNull);
  });
}
