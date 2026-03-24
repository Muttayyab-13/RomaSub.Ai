import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/video_player_provider.dart';

/// Playback controls bar: play/pause, seek slider, time, volume, subtitle toggle
class VideoControls extends ConsumerWidget {
  const VideoControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoPlayerNotifierProvider);
    final notifier = ref.read(videoPlayerNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final positionMs = state.position.inMilliseconds.toDouble();
    final durationMs = state.duration.inMilliseconds.toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.getPrimary(isDark),
              inactiveTrackColor: AppColors.getBorder(isDark),
              thumbColor: AppColors.getPrimary(isDark),
            ),
            child: Slider(
              value: durationMs > 0 ? positionMs.clamp(0, durationMs) : 0,
              min: 0,
              max: durationMs > 0 ? durationMs : 1,
              onChanged: durationMs > 0
                  ? (value) {
                      notifier.seek(Duration(milliseconds: value.round()));
                    }
                  : null,
            ),
          ),

          // Controls row
          Row(
            children: [
              // Play/Pause
              IconButton(
                icon: Icon(
                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.getTextPrimary(isDark),
                ),
                iconSize: AppSizes.iconMd,
                onPressed: () => notifier.togglePlayPause(),
                tooltip: state.isPlaying ? 'Pause' : 'Play',
              ),

              // Time display
              Text(
                '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: AppColors.getTextSecondary(isDark),
                  fontFamily: 'monospace',
                ),
              ),

              const Spacer(),

              // Volume
              Icon(
                state.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: AppSizes.iconSm,
                color: AppColors.getTextSecondary(isDark),
              ),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: AppColors.getTextSecondary(isDark),
                    inactiveTrackColor: AppColors.getBorder(isDark),
                    thumbColor: AppColors.getTextSecondary(isDark),
                  ),
                  child: Slider(
                    value: state.volume,
                    onChanged: (v) => notifier.setVolume(v),
                  ),
                ),
              ),

              // Subtitle toggle
              IconButton(
                icon: Icon(
                  state.subtitlesVisible
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_off_rounded,
                  color: state.subtitlesVisible
                      ? AppColors.getPrimary(isDark)
                      : AppColors.getTextSecondary(isDark),
                ),
                iconSize: AppSizes.iconSm,
                onPressed: () => notifier.toggleSubtitles(),
                tooltip: state.subtitlesVisible
                    ? 'Hide subtitles'
                    : 'Show subtitles',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
