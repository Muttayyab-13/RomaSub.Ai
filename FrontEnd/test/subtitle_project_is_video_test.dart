// FrontEnd/test/subtitle_project_is_video_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

Map<String, dynamic> _base(Map<String, dynamic> overrides) => {
      'subtitle_id': 's1',
      'file_id': 'f1',
      'project_name': 'p',
      'original_filename': 'clip.mp4',
      'segments': <dynamic>[],
      'segment_count': 0,
      'created_at': 'now',
      'updated_at': 'now',
      ...overrides,
    };

void main() {
  test('uses backend is_video when present', () {
    final p = SubtitleProject.fromJson(_base({'is_video': true}));
    expect(p.isVideo, isTrue);
  });

  test('false when backend says audio source', () {
    final p = SubtitleProject.fromJson(
        _base({'original_filename': 'voice.wav', 'is_video': false}));
    expect(p.isVideo, isFalse);
  });

  test('falls back to filename when is_video absent (mp4)', () {
    final json = _base({})..remove('is_video');
    final p = SubtitleProject.fromJson(json);
    expect(p.isVideo, isTrue);
  });

  test('falls back to filename when is_video absent (wav)', () {
    final json = _base({'original_filename': 'voice.wav'})..remove('is_video');
    final p = SubtitleProject.fromJson(json);
    expect(p.isVideo, isFalse);
  });
}
