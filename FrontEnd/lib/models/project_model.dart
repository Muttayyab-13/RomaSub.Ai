import 'package:flutter/material.dart';

enum ProjectType { video, audio }

class Project {
  final String id;
  final String title;
  final String fileName;
  final String timeAgo;
  final ProjectType type;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.title,
    required this.fileName,
    required this.timeAgo,
    required this.type,
    required this.createdAt,
  });

  IconData get icon =>
      type == ProjectType.video ? Icons.video_file : Icons.audiotrack;

  // For future API integration
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      title: json['title'],
      fileName: json['fileName'],
      timeAgo: json['timeAgo'],
      type: json['type'] == 'video' ? ProjectType.video : ProjectType.audio,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'fileName': fileName,
    'timeAgo': timeAgo,
    'type': type == ProjectType.video ? 'video' : 'audio',
    'createdAt': createdAt.toIso8601String(),
  };

  // Sample data
  static List<Project> getSampleData() => [
    Project(
      id: '1',
      title: 'News Report',
      fileName: 'News Report.mp4',
      timeAgo: '2 hours ago',
      type: ProjectType.video,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Project(
      id: '2',
      title: 'Podcast Audio',
      fileName: 'Podcast Audio.mp3',
      timeAgo: '1 day ago',
      type: ProjectType.audio,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Project(
      id: '3',
      title: 'Interview Clip',
      fileName: 'Interview Clip.mp4',
      timeAgo: '5 days ago',
      type: ProjectType.video,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Project(
      id: '4',
      title: 'Lecture Recording',
      fileName: 'Lecture Recording.wav',
      timeAgo: '1 week ago',
      type: ProjectType.audio,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Project(
      id: '5',
      title: 'Documentary',
      fileName: 'Documentary.mp4',
      timeAgo: '2 weeks ago',
      type: ProjectType.video,
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    Project(
      id: '6',
      title: 'Tutorial Video',
      fileName: 'Tutorial Video.avi',
      timeAgo: '3 weeks ago',
      type: ProjectType.video,
      createdAt: DateTime.now().subtract(const Duration(days: 21)),
    ),
  ];
}
