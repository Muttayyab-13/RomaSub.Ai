import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/video_player_provider.dart';
import 'subtitle_overlay.dart';
import 'video_controls.dart';

/// Left panel: video player with subtitle overlay and playback controls
class VideoPreviewPanel extends ConsumerWidget {
  const VideoPreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(videoPlayerNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        border: Border(
          right: BorderSide(color: AppColors.getBorder(isDark), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Video area with subtitle overlay
          Expanded(
            child: Container(
              color: Colors.black,
              child: playerState.controller != null
                  ? Stack(
                      children: [
                        // Video
                        Center(
                          child: Video(
                            controller: playerState.controller!,
                            controls: NoVideoControls,
                          ),
                        ),

                        // Buffering indicator
                        if (playerState.isBuffering)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),

                        // Subtitle overlay at bottom
                        const Positioned.fill(
                          child: SubtitleOverlay(),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            size: AppSizes.iconXl,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            playerState.error ?? 'Loading video...',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: AppSizes.fontSm,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Playback controls
          const VideoControls(),
        ],
      ),
    );
  }
}
