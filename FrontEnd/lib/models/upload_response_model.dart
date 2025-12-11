/// Upload response model from media upload endpoint
class UploadResponseModel {
  final String fileId;
  final String filename;
  final int fileSize;
  final double fileSizeMb;
  final bool isVideo;
  final String? message;

  UploadResponseModel({
    required this.fileId,
    required this.filename,
    required this.fileSize,
    required this.fileSizeMb,
    required this.isVideo,
    this.message,
  });

  /// Create UploadResponseModel from JSON (API response)
  factory UploadResponseModel.fromJson(Map<String, dynamic> json) {
    return UploadResponseModel(
      fileId: json['file_id'] as String,
      filename: json['filename'] as String,
      fileSize: json['file_size'] as int,
      fileSizeMb: (json['file_size_mb'] as num).toDouble(),
      isVideo: json['is_video'] as bool,
      message: json['message'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'filename': filename,
      'file_size': fileSize,
      'file_size_mb': fileSizeMb,
      'is_video': isVideo,
      'message': message,
    };
  }

  /// Get file size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${fileSizeMb.toStringAsFixed(2)} MB';
  }

  /// Check if file is audio
  bool get isAudio => !isVideo;

  @override
  String toString() =>
      'UploadResponseModel(fileId: $fileId, filename: $filename, isVideo: $isVideo)';
}
