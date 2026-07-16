/// Editable subtitle segment for the editor
class EditableSegment {
  int id;
  double start;
  double end;
  String urduText;
  String romanUrduText;
  bool isEdited;

  EditableSegment({
    required this.id,
    required this.start,
    required this.end,
    this.urduText = '',
    this.romanUrduText = '',
    this.isEdited = false,
  });

  double get duration => end - start;

  bool get isValid =>
      romanUrduText.length <= 500 &&
      urduText.length <= 500 &&
      duration >= 0.5 &&
      duration <= 7.0 &&
      end > start;

  String? get validationError {
    if (end <= start) return 'End time must be after start time';
    if (duration < 0.5) return 'Duration must be at least 0.5s';
    if (duration > 7.0) return 'Duration must not exceed 7.0s';
    if (romanUrduText.length > 500) return 'Text exceeds 500 characters';
    return null;
  }

  /// Minimum gap the backend enforces between segments, in seconds.
  /// Mirrors MIN_GAP_BETWEEN_SEGMENTS in app/services/subtitle.py.
  static const double minGapSeconds = 0.1;

  /// Above this, captions outrun a comfortable reading pace. 21 chars/sec is
  /// the common broadcast-subtitling ceiling.
  static const double maxComfortableCps = 21.0;

  /// The text that actually reaches the viewer: Roman Urdu, falling back to
  /// Urdu. Mirrors the caption rule used everywhere else, including export.
  String get displayText =>
      romanUrduText.isNotEmpty ? romanUrduText : urduText;

  /// Reading rate in characters per second. Zero (not infinity) when the
  /// duration is zero, so the UI never has to render an infinity.
  double get charsPerSecond {
    if (duration <= 0) return 0.0;
    return displayText.length / duration;
  }

  bool get isComfortableReadingRate => charsPerSecond <= maxComfortableCps;

  /// True when [next] starts before this segment ends, or closer than the
  /// backend's minimum gap. Drives the warning marker in the segment list.
  bool overlapsNext(EditableSegment? next) {
    if (next == null) return false;
    return next.start - end < minGapSeconds;
  }

  /// Format timestamp as HH:MM:SS,mmm
  static String formatTimestamp(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = (seconds % 60).floor();
    final millis = ((seconds % 1) * 1000).floor();
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }

  String get startFormatted => formatTimestamp(start);
  String get endFormatted => formatTimestamp(end);

  EditableSegment copyWith({
    int? id,
    double? start,
    double? end,
    String? urduText,
    String? romanUrduText,
    bool? isEdited,
  }) {
    return EditableSegment(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      urduText: urduText ?? this.urduText,
      romanUrduText: romanUrduText ?? this.romanUrduText,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  factory EditableSegment.fromJson(Map<String, dynamic> json) {
    return EditableSegment(
      id: json['id'] as int,
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      urduText: json['urdu_text'] as String? ?? '',
      romanUrduText: json['roman_urdu_text'] as String? ?? '',
      isEdited: json['is_edited'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
      'urdu_text': urduText,
      'roman_urdu_text': romanUrduText,
      'is_edited': isEdited,
    };
  }
}

/// Subtitle project containing all segments and metadata
class SubtitleProject {
  final String subtitleId;
  final String fileId;
  final String projectName;
  final String originalFilename;
  final bool isVideo;
  final List<EditableSegment> segments;
  final int segmentCount;
  final double? fileDuration;
  final String createdAt;
  final String updatedAt;

  SubtitleProject({
    required this.subtitleId,
    required this.fileId,
    required this.projectName,
    required this.originalFilename,
    required this.isVideo,
    required this.segments,
    required this.segmentCount,
    this.fileDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  SubtitleProject copyWith({
    String? subtitleId,
    String? fileId,
    String? projectName,
    String? originalFilename,
    bool? isVideo,
    List<EditableSegment>? segments,
    int? segmentCount,
    double? fileDuration,
    String? createdAt,
    String? updatedAt,
  }) {
    return SubtitleProject(
      subtitleId: subtitleId ?? this.subtitleId,
      fileId: fileId ?? this.fileId,
      projectName: projectName ?? this.projectName,
      originalFilename: originalFilename ?? this.originalFilename,
      isVideo: isVideo ?? this.isVideo,
      segments: segments ?? this.segments,
      segmentCount: segmentCount ?? this.segmentCount,
      fileDuration: fileDuration ?? this.fileDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Set<String> _videoExtensions = {
    'mp4', 'avi', 'mkv', 'mov', 'webm',
  };

  static bool _deriveIsVideo(String filename) {
    if (!filename.contains('.')) return false;
    return _videoExtensions.contains(filename.split('.').last.toLowerCase());
  }

  factory SubtitleProject.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>? ?? [];
    final originalFilename = json['original_filename'] as String? ?? '';
    return SubtitleProject(
      subtitleId: json['subtitle_id'] as String,
      fileId: json['file_id'] as String,
      projectName: json['project_name'] as String? ?? '',
      originalFilename: originalFilename,
      isVideo: (json['is_video'] as bool?) ??
          _deriveIsVideo(originalFilename),
      segments: segmentsList
          .map((s) => EditableSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      segmentCount: json['segment_count'] as int? ?? 0,
      fileDuration: (json['file_duration'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subtitle_id': subtitleId,
      'file_id': fileId,
      'project_name': projectName,
      'original_filename': originalFilename,
      'is_video': isVideo,
      'segments': segments.map((s) => s.toJson()).toList(),
      'segment_count': segmentCount,
      'file_duration': fileDuration,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
