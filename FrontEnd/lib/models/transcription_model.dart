/// Transcription segment with timestamp and text
class TranscriptionSegment {
  final int id;
  final double start;
  final double end;
  final String text;

  TranscriptionSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  /// Create TranscriptionSegment from JSON
  factory TranscriptionSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptionSegment(
      id: json['id'] as int,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'start': start, 'end': end, 'text': text};
  }

  /// Get duration in seconds
  double get duration => end - start;

  /// Format timestamp as SRT time (HH:MM:SS,mmm)
  String formatTimestamp(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = (seconds % 60).floor();
    final millis = ((seconds % 1) * 1000).floor();
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }

  /// Get SRT formatted segment
  String toSrtFormat() {
    return '${formatTimestamp(start)} --> ${formatTimestamp(end)}\n$text';
  }

  @override
  String toString() =>
      'TranscriptionSegment(id: $id, start: $start, end: $end, text: $text)';
}

/// Transcription response model from ASR endpoint
class TranscriptionModel {
  final String fileId;
  final String language;
  final String text;
  final List<TranscriptionSegment> segments;
  final double duration;

  TranscriptionModel({
    required this.fileId,
    required this.language,
    required this.text,
    required this.segments,
    required this.duration,
  });

  /// Create TranscriptionModel from JSON (API response)
  factory TranscriptionModel.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>?;
    final segments =
        segmentsList
            ?.map(
              (s) => TranscriptionSegment.fromJson(s as Map<String, dynamic>),
            )
            .toList() ??
        [];

    // Parse duration from 'audio_duration_seconds' or 'duration' field
    final duration =
        (json['audio_duration_seconds'] as num?)?.toDouble() ??
        (json['duration'] as num?)?.toDouble() ??
        0.0;

    return TranscriptionModel(
      fileId: json['file_id'] as String,
      language: json['language'] as String? ?? 'ur',
      text: json['text'] as String,
      segments: segments,
      duration: duration,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'language': language,
      'text': text,
      'segments': segments.map((s) => s.toJson()).toList(),
      'duration': duration,
    };
  }

  /// Get total segment count
  int get segmentCount => segments.length;

  /// Get formatted duration (MM:SS)
  String get durationFormatted {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Generate full SRT content
  String toSrtContent() {
    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      buffer.writeln(i + 1);
      buffer.writeln(segments[i].toSrtFormat());
      buffer.writeln();
    }
    return buffer.toString();
  }

  @override
  String toString() =>
      'TranscriptionModel(fileId: $fileId, language: $language, segments: ${segments.length})';
}
