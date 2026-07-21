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
                        // Video. libmpv's own rotation is disabled (it crashes
                        // the SW renderer on rotated clips), so re-apply the
                        // container rotation here. For quarter/three-quarter
                        // turns the box axes swap, so hand Video the swapped
                        // extents and let RotatedBox turn it back upright.
                        Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final turns = playerState.rotationQuarterTurns;
                              final swap = turns.isOdd;
                              Widget video = Video(
                                controller: playerState.controller!,
                                controls: NoVideoControls,
                                width: swap
                                    ? constraints.maxHeight
                                    : constraints.maxWidth,
                                height: swap
                                    ? constraints.maxWidth
                                    : constraints.maxHeight,
                              );
                              if (turns != 0) {
                                video = RotatedBox(
                                  quarterTurns: turns,
                                  child: video,
                                );
                              }
                              return video;
                            },
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
                        const Positioned.fill(child: SubtitleOverlay()),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              playerState.mediaUnavailable
                                  ? Icons.cloud_off_rounded
                                  : Icons.videocam_off_rounded,
                              size: AppSizes.iconXl,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              playerState.mediaUnavailable
                                  ? 'This project\'s media file is no longer '
                                        'available. Please re-upload the video to '
                                        'edit or export captions.'
                                  : (playerState.error ?? 'Loading video...'),
                              textAlign: TextAlign.center,
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
          ),

          // Playback controls
          const VideoControls(),
        ],
      ),
    );
  }
}
