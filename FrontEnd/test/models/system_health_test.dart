// FrontEnd/test/models/system_health_test.dart
//
// SystemHealth is the honest view over GET /health. Reachability is the only
// hard truth (did the call return); the model strings are the configured
// values the backend reports. `unreachable` is the red fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/system_health.dart';

void main() {
  test('fromJson reads the configured model fields and is reachable', () {
    final h = SystemHealth.fromJson({
      'status': 'healthy',
      'database': 'connected',
      'whisper_model': 'whisper-large-v3-turbo',
      'm2m100_model': 'facebook/m2m100_418M',
      'transliteration_device': 'cuda',
    });

    expect(h.reachable, isTrue);
    expect(h.whisperModel, 'whisper-large-v3-turbo');
    expect(h.transliterationModel, 'facebook/m2m100_418M');
    expect(h.device, 'cuda');
  });

  test('fromJson tolerates missing model fields', () {
    final h = SystemHealth.fromJson({'status': 'healthy'});
    expect(h.reachable, isTrue);
    expect(h.whisperModel, isNull);
    expect(h.transliterationModel, isNull);
    expect(h.device, isNull);
  });

  test('unreachable is not reachable and carries no model info', () {
    const h = SystemHealth.unreachable();
    expect(h.reachable, isFalse);
    expect(h.whisperModel, isNull);
  });
}
