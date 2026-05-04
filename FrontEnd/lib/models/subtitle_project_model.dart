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
    required this.segments,
    required this.segmentCount,
    this.fileDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubtitleProject.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>? ?? [];
    return SubtitleProject(
      subtitleId: json['subtitle_id'] as String,
      fileId: json['file_id'] as String,
      projectName: json['project_name'] as String? ?? '',
      originalFilename: json['original_filename'] as String? ?? '',
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
      'segments': segments.map((s) => s.toJson()).toList(),
      'segment_count': segmentCount,
      'file_duration': fileDuration,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
