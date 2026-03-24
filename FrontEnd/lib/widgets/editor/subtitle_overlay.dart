import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/video_player_provider.dart';
import '../../providers/subtitle_editor_provider.dart';
import '../../providers/realtime_subtitle_provider.dart';
import '../../models/subtitle_project_model.dart';

/// Real-time subtitle overlay displayed on top of the video
///
/// Positioned at bottom 10% of video frame, center-aligned.
/// Per FR-8: 70% opacity black background, auto-scaled font,
/// 200ms fade transitions, ±50ms sync accuracy.
///
/// Dual-source: reads from realtime provider during streaming mode,
/// falls back to editor provider when in editor mode.
class SubtitleOverlay extends ConsumerWidget {
  const SubtitleOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(videoPlayerNotifierProvider);
    final realtimeState = ref.watch(realtimeNotifierProvider);
    final editorState = ref.watch(editorNotifierProvider);

    if (!playerState.subtitlesVisible) return const SizedBox.shrink();

    final currentTime = playerState.positionSeconds;

    // Dual-source: use realtime during streaming, editor when project loaded
    final bool useRealtime = realtimeState.canPlay &&
        editorState.project == null;

    int? segmentIndex;
    EditableSegment? segment;

    if (useRealtime) {
      segmentIndex = realtimeState.getSegmentAtTime(currentTime);
      if (segmentIndex != null) {
        segment = realtimeState.segments[segmentIndex];
      }
    } else {
      segmentIndex = ref
          .read(editorNotifierProvider.notifier)
          .getSegmentAtTime(currentTime);
      if (segmentIndex != null && segmentIndex < editorState.segments.length) {
        segment = editorState.segments[segmentIndex];
      }
    }

    if (segment == null) {
      return const _FadingSubtitle(text: null);
    }

    final text = segment.romanUrduText.isNotEmpty
        ? segment.romanUrduText
        : segment.urduText;

    if (text.isEmpty) return const _FadingSubtitle(text: null);

    return _FadingSubtitle(text: text);
  }
}

/// Handles the fade transition for subtitle text
class _FadingSubtitle extends StatelessWidget {
  final String? text;

  const _FadingSubtitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, left: 24.0, right: 24.0),
        child: AnimatedOpacity(
          opacity: text != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: text != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final fontSize = _calculateFontSize(constraints.maxWidth);
                      return Text(
                        text!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Auto-scale font based on available width (proxy for resolution)
  double _calculateFontSize(double width) {
    if (width >= 1920) return 24.0; // 4K-ish
    if (width >= 960) return 18.0; // 1080p-ish
    return 14.0; // 720p and below
  }
}
