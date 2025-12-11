import 'package:flutter/material.dart';

enum ExportFormat { srt, vtt, txt }

class Export {
  final String id;
  final String fileName;
  final String timeAgo;
  final String size;
  final ExportFormat format;

  Export({
    required this.id,
    required this.fileName,
    required this.timeAgo,
    required this.size,
    required this.format,
  });

  IconData get icon {
    switch (format) {
      case ExportFormat.srt:
        return Icons.subtitles;
      case ExportFormat.vtt:
        return Icons.closed_caption;
      case ExportFormat.txt:
        return Icons.text_snippet;
    }
  }

  static List<Export> getSampleData() => [
    Export(
      id: '1',
      fileName: 'News Report - Subtitles.srt',
      timeAgo: 'Exported 2 hours ago',
      size: '2.3 MB',
      format: ExportFormat.srt,
    ),
    Export(
      id: '2',
      fileName: 'Podcast Audio - Captions.vtt',
      timeAgo: 'Exported 1 day ago',
      size: '1.8 MB',
      format: ExportFormat.vtt,
    ),
    Export(
      id: '3',
      fileName: 'Interview Clip - Transcript.txt',
      timeAgo: 'Exported 5 days ago',
      size: '892 KB',
      format: ExportFormat.txt,
    ),
    Export(
      id: '4',
      fileName: 'Lecture Recording - Subtitles.srt',
      timeAgo: 'Exported 1 week ago',
      size: '3.1 MB',
      format: ExportFormat.srt,
    ),
  ];
}
