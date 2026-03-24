import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/realtime_subtitle_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../services/api/api_config.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/editor/subtitle_overlay.dart';
import '../../widgets/editor/video_controls.dart';

/// Real-time subtitle viewer screen.
///
/// Shows video playback with live-streaming subtitles.
/// Phases: connecting → buffering → streaming (playback starts) → complete.
/// On complete, user can transition to the subtitle editor.
class RealtimeViewerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String filename;

  const RealtimeViewerScreen({
    super.key,
    required this.fileId,
    required this.filename,
  });

  @override
  ConsumerState<RealtimeViewerScreen> createState() =>
      _RealtimeViewerScreenState();
}

class _RealtimeViewerScreenState extends ConsumerState<RealtimeViewerScreen> {
  bool _videoStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreaming();
    });
  }

  Future<void> _startStreaming() async {
    // Start the SSE stream
    ref.read(realtimeNotifierProvider.notifier).startStreaming(widget.fileId);
  }

  void _startVideoWhenReady(RealtimeState rtState) {
    if (!_videoStarted && rtState.canPlay) {
      _videoStarted = true;
      final videoUrl = ApiConfig.mediaStreamUrl(widget.fileId);
      final playerNotifier = ref.read(videoPlayerNotifierProvider.notifier);
      playerNotifier.initialize(videoUrl).then((_) {
        playerNotifier.play();
        // Hook seek callback for debounced seek notification
        playerNotifier.onSeekCallback = (seconds) {
          ref.read(realtimeNotifierProvider.notifier).notifySeek(seconds);
        };
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Space - Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      ref.read(videoPlayerNotifierProvider.notifier).togglePlayPause();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rtState = ref.watch(realtimeNotifierProvider);
    final playerState = ref.watch(videoPlayerNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-start video when buffer is ready
    _startVideoWhenReady(rtState);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        body: Row(
          children: [
            const Sidebar(currentRoute: AppRoutes.realtimeViewer),
            Expanded(
              child: Column(
                children: [
                  // Top bar
                  _buildTopBar(isDark, rtState),

                  // Video area
                  Expanded(
                    child: rtState.phase == RealtimePhase.connecting ||
                            (rtState.phase == RealtimePhase.buffering &&
                                !_videoStarted)
                        ? _buildBufferingState(isDark, rtState)
                        : _buildVideoArea(isDark, playerState, rtState),
                  ),

                  // Progress bar + actions
                  _buildBottomBar(isDark, rtState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, RealtimeState rtState) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceVariant(isDark),
        border: Border(
          bottom: BorderSide(color: AppColors.getBorder(isDark)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                size: 20, color: AppColors.getTextPrimary(isDark)),
            tooltip: 'Back to Dashboard',
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
          Icon(Icons.live_tv_rounded,
              size: AppSizes.iconSm,
              color: AppColors.getTextSecondary(isDark)),
          const SizedBox(width: AppSizes.xs),
          Flexible(
            child: Text(
              widget.filename,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Phase indicator
          _buildPhaseChip(isDark, rtState),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(bool isDark, RealtimeState rtState) {
    Color color;
    String label;
    switch (rtState.phase) {
      case RealtimePhase.connecting:
        color = AppColors.warning;
        label = 'Connecting...';
      case RealtimePhase.buffering:
        color = AppColors.warning;
        label = 'Buffering...';
      case RealtimePhase.streaming:
        color = AppColors.success;
        label = 'Live';
      case RealtimePhase.complete:
        color = AppColors.getPrimary(isDark);
        label = 'Complete';
      case RealtimePhase.error:
        color = AppColors.error;
        label = 'Error';
      case RealtimePhase.idle:
        color = AppColors.getTextSecondary(isDark);
        label = 'Idle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rtState.phase == RealtimePhase.streaming)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferingState(bool isDark, RealtimeState rtState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.getPrimary(isDark)),
          const SizedBox(height: AppSizes.md),
          Text(
            rtState.phase == RealtimePhase.connecting
                ? 'Connecting to stream...'
                : 'Preparing subtitles...',
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          if (rtState.chunksTotal > 0) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              '${rtState.chunksReady}/${rtState.chunksTotal} chunks processed',
              style: TextStyle(
                fontSize: AppSizes.fontXs,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ],
          if (rtState.error != null) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              rtState.error!,
              style: TextStyle(fontSize: AppSizes.fontSm, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoArea(
      bool isDark, VideoPlayerState playerState, RealtimeState rtState) {
    return Container(
      color: Colors.black,
      child: playerState.controller != null
          ? Stack(
              children: [
                Center(
                  child: Video(
                    controller: playerState.controller!,
                    controls: NoVideoControls,
                  ),
                ),
                if (playerState.isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                // Subtitle overlay (reads from realtime provider)
                const Positioned.fill(child: SubtitleOverlay()),
              ],
            )
          : Center(
              child: Text(
                playerState.error ?? 'Loading video...',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
    );
  }

  Widget _buildBottomBar(bool isDark, RealtimeState rtState) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark)),
        ),
      ),
      child: Column(
        children: [
          // Video controls (when video is loaded)
          if (_videoStarted) const VideoControls(),

          const SizedBox(height: AppSizes.xs),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: rtState.progress,
                    backgroundColor: AppColors.getBorder(isDark),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rtState.phase == RealtimePhase.complete
                          ? AppColors.success
                          : AppColors.getPrimary(isDark),
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                '${rtState.chunksReady}/${rtState.chunksTotal} chunks',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              Text(
                ' | ${rtState.segments.length} subtitles',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ],
          ),

          // Open Editor button (when complete)
          if (rtState.phase == RealtimePhase.complete) ...[
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Create subtitle project, then navigate to editor
                  final project = await ref
                      .read(realtimeNotifierProvider.notifier)
                      .createProjectForEditor(widget.filename);

                  if (project != null && mounted) {
                    // Navigate to editor with the transcription data
                    // The editor needs a TranscriptionModel, but we can
                    // navigate directly since the project is already created
                    AppRoutes.replace(context, AppRoutes.editor, arguments: {
                      'fileId': widget.fileId,
                      'transcription': null, // Editor will load from existing project
                    });
                  }
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Open Subtitle Editor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimary(isDark),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
